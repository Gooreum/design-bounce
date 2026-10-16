#!/usr/bin/env bash
set -euo pipefail
# init.sh — 채택 프로젝트 온보딩: config · state · 게이트 훅 배선을 한 번에 준비한다.
#
# 사용법 (채택 프로젝트 루트에서):
#   install.sh init [--write] [--project <dir>]
#   (또는 bash hooks/init.sh ... 직접 실행)
#
#   --write          .claude/settings.json 에 PreToolUse 훅을 병합 (기본: 스니펫 출력만)
#   --project <dir>  대상 프로젝트 디렉토리 (기본: cwd)
#
# 단계:
#   1. detect_adapter : app.json / app.config.* / package.json expo 의존성 → rn-expo
#   2. gen_config     : design-bounce.config.json 생성 (이미 있으면 보존)
#   3. init_state     : .design-bounce/state.json = {phase:design, spec_approved:false, current_step:0}
#                       (이미 있으면 보존)
#   4. hook_snippet / merge_settings : 훅 스니펫 출력 또는 --write 시 멱등 병합(+ .bak 백업)
#   5. doctor         : 필수 필드 / TODO placeholder 점검 + navigate --dry-run smoke test
#
# 경로 override (훅/어댑터와 같은 규칙):
#   DESIGN_BOUNCE_DIR    : state 디렉토리 (기본 .design-bounce)
#   DESIGN_BOUNCE_CONFIG : config 경로 (기본 design-bounce.config.json)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"
WRITE=0; PROJECT="."

while [ $# -gt 0 ]; do
  case "$1" in
    --write)   WRITE=1;;
    --project) [ $# -ge 2 ] || { echo "--project <dir> 필요" >&2; exit 2; }
               PROJECT="$2"; shift;;
    -h|--help)
      echo "usage: install.sh init [--write] [--project <dir>]"
      echo "  --write          .claude/settings.json 에 게이트 훅 병합 (기본: 스니펫 출력만)"
      echo "  --project <dir>  대상 프로젝트 디렉토리 (기본: 현재 디렉토리)"
      exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
  shift
done

command -v jq >/dev/null || { echo "❌ jq 없음 — init에 필요: brew install jq" >&2; exit 1; }
cd "$PROJECT" || { echo "❌ 프로젝트 디렉토리 없음: $PROJECT" >&2; exit 1; }

# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"
SETTINGS=".claude/settings.json"
TODO="TODO-"            # placeholder 접두사 (doctor가 검사)
SUMMARY=(); FAILED=0

note() { SUMMARY+=("$1"); }

# --- 1. 어댑터 감지 (SKILL.md 플랫폼 자동 감지 규칙과 동일) ---
detect_adapter() {
  if [ -f app.json ] || [ -f app.config.js ] || [ -f app.config.ts ]; then
    echo "rn-expo"; return 0
  fi
  if [ -f package.json ] && \
     jq -e '(.dependencies.expo // .devDependencies.expo) != null' package.json >/dev/null 2>&1; then
    echo "rn-expo"; return 0
  fi
  return 1
}

# app.json 의 expo 필드 하나를 읽는다 (없거나 파싱 실패면 빈 값)
app_json_field() {
  [ -f app.json ] || return 0
  jq -r "(.expo // .) | $1 // empty" app.json 2>/dev/null || true
}

# --- 2. config 생성 ---
gen_config() {
  local adapter="$1" scheme bundle route
  if [ -f "$CFG" ]; then
    echo "ℹ️  기존 config 보존: $CFG"; note "config: 보존"; return 0
  fi
  # expo.scheme 은 문자열 또는 배열일 수 있다
  scheme=$(app_json_field '.scheme | if type == "array" then .[0] else . end')
  bundle=$(app_json_field '.ios.bundleIdentifier')
  if [ -z "$scheme" ]; then
    scheme="${TODO}scheme"
    echo "⚠️  app.json 에서 expo.scheme 을 찾지 못함 → placeholder '$scheme' (직접 채워야 함)"
  fi
  if [ -z "$bundle" ]; then
    bundle="${TODO}bundleId"
    echo "⚠️  app.json 에서 expo.ios.bundleIdentifier 를 찾지 못함 → placeholder '$bundle'"
  fi
  route="${TODO}route"
  for r in "app/(tabs)/index.tsx" "app/index.tsx"; do
    [ -f "$r" ] && { route="$r"; break; }
  done
  mkdir -p "$(dirname "$CFG")"
  jq -n --arg adapter "$adapter" --arg scheme "$scheme" --arg bundle "$bundle" \
        --arg route "$route" --arg shots "$DB_STATE_DIR/shots" '{
    adapter: $adapter,
    scheme: $scheme,
    bundleId: $bundle,
    captureDir: $shots,
    screens: { home: { deeplink: ($scheme + "://home"), route: $route } }
  }' > "$CFG"
  echo "✅ config 생성: $CFG (adapter=$adapter, scheme=$scheme)"; note "config: 생성"
}

# --- 3. state 초기화 ---
init_state() {
  if [ -f "$DB_STATE_FILE" ]; then
    if jq -e 'type == "object"' "$DB_STATE_FILE" >/dev/null 2>&1; then
      echo "ℹ️  기존 state 보존: $DB_STATE_FILE (phase=$(db_state_field phase '?'))"
    else
      echo "⚠️  state.json 파싱 실패 — 게이트가 통과(fail-open)함. 직접 확인 필요: $DB_STATE_FILE"
    fi
    note "state: 보존"; return 0
  fi
  mkdir -p "$DB_STATE_DIR"
  echo '{"phase":"design","spec_approved":false,"current_step":0}' | jq . > "$DB_STATE_FILE"
  echo "✅ state 생성: $DB_STATE_FILE (phase=design)"; note "state: 생성"
}

# --- 4. 훅 배선 ---
# 훅 command: 절대경로 (상대경로는 훅 실행 cwd 에 따라 깨짐). state 경로 override 시 env 접두.
hook_cmd() {
  local cmd
  cmd=$(printf '%q' "$REPO_DIR/hooks/$1")
  if [ -n "${DESIGN_BOUNCE_DIR:-}" ]; then
    cmd="DESIGN_BOUNCE_DIR=$(printf '%q' "$DESIGN_BOUNCE_DIR") $cmd"
  fi
  printf '%s' "$cmd"
}
HOOK_CMDS_JSON=$(jq -n --arg a "$(hook_cmd spec-gate.sh)" --arg b "$(hook_cmd screenshot-gate.sh)" '[$a, $b]')

hook_snippet() {
  jq -n --argjson cmds "$HOOK_CMDS_JSON" '{hooks: {PreToolUse: [
    {matcher: "Write|Edit", hooks: ($cmds | map({type: "command", command: .}))}
  ]}}'
}

# 기존 PreToolUse 어디에도 없는 command 만 추가한다.
# matcher == "Write|Edit" 항목이 있으면 그 hooks 에, 없으면 새 항목을 append. 다른 키는 보존.
MERGE_JQ='
  .hooks = (.hooks // {}) | .hooks.PreToolUse = (.hooks.PreToolUse // []) |
  [.hooks.PreToolUse[].hooks[]?.command] as $have |
  [$cmds[] | select(. as $c | any($have[]; . == $c) | not)] as $missing |
  if ($missing | length) == 0 then . else
    ($missing | map({type: "command", command: .})) as $new |
    ([.hooks.PreToolUse | to_entries[] | select(.value.matcher == "Write|Edit") | .key] | .[0]) as $i |
    if $i == null then .hooks.PreToolUse += [{matcher: "Write|Edit", hooks: $new}]
    else .hooks.PreToolUse[$i].hooks = ((.hooks.PreToolUse[$i].hooks // []) + $new) end
  end'

print_snippet() {
  echo "👉 아래를 $SETTINGS 에 병합하세요 (또는 'install.sh init --write'):"
  hook_snippet
}

merge_settings() {
  local cur merged
  if [ -f "$SETTINGS" ]; then
    if ! cur=$(jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1 && cat "$SETTINGS"); then
      echo "❌ $SETTINGS 가 올바른 JSON 객체가 아님 — --write 거부 (파일 미변경)"
      print_snippet; note "settings: 병합 거부(깨진 JSON)"; FAILED=1; return 0
    fi
  else
    cur='{}'
  fi
  merged=$(printf '%s' "$cur" | jq --argjson cmds "$HOOK_CMDS_JSON" "$MERGE_JQ")
  if [ -f "$SETTINGS" ] && [ "$(printf '%s' "$cur" | jq -S .)" = "$(printf '%s' "$merged" | jq -S .)" ]; then
    echo "ℹ️  훅 이미 배선됨: $SETTINGS"; note "settings: 건너뜀(이미 배선)"; return 0
  fi
  mkdir -p "$(dirname "$SETTINGS")"
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
  printf '%s\n' "$merged" > "$SETTINGS"
  echo "✅ 훅 배선: $SETTINGS$([ -f "$SETTINGS.bak" ] && echo " (백업: $SETTINGS.bak)")"
  note "settings: 병합"
}

# --- 5. 점검 (경고만, 실패 아님) ---
doctor() {
  local missing=() k v first adapter_sh out
  if ! jq -e 'type == "object"' "$CFG" >/dev/null 2>&1; then
    echo "⚠️  config 파싱 실패: $CFG"; return 0
  fi
  for k in adapter scheme screens; do
    jq -e --arg k "$k" 'has($k)' "$CFG" >/dev/null || missing+=("$k — 필수 필드")
  done
  jq -e '(.screens // {}) | length > 0' "$CFG" >/dev/null || missing+=("screens — 화면 1개 이상 필요")
  # 값이 TODO- 로 시작하는 placeholder 목록 (경로 형태로)
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    case "$v" in
      scheme)   missing+=("scheme — 딥링크(navigate)에 필요");;
      bundleId) missing+=("bundleId — launch에 필요");;
      *)        missing+=("$v — placeholder 값을 채워야 함");;
    esac
  done < <(jq -r --arg t "$TODO" '
    [paths(strings) as $p | select(getpath($p) | startswith($t)) | $p | map(tostring) | join(".")]
    | map(select(test("\\.deeplink$") | not)) | .[]' "$CFG")
  jq -e 'has("bundleId")' "$CFG" >/dev/null || missing+=("bundleId — launch에 필요")

  first=$(jq -r '(.screens // {}) | keys_unsorted[0] // empty' "$CFG")
  adapter_sh="$REPO_DIR/adapters/$(jq -r '.adapter // empty' "$CFG")/adapter.sh"
  if [ -n "$first" ] && [ -f "$adapter_sh" ]; then
    if out=$(DESIGN_BOUNCE_CONFIG="$CFG" bash "$adapter_sh" navigate "$first" --dry-run 2>&1); then
      echo "✅ smoke test: adapter navigate $first --dry-run → $out"
    else
      missing+=("screens.$first.deeplink — navigate dry-run 실패: $out")
    fi
  elif [ ! -f "$adapter_sh" ]; then
    missing+=("adapter — 어댑터 없음: $adapter_sh")
  fi

  if [ ${#missing[@]} -eq 0 ]; then
    echo "✅ config 점검 통과"
  else
    echo "⚠️  config 점검 — $CFG 에서 채워야 할 항목:"
    for v in "${missing[@]}"; do echo "   - 누락: $v"; done
  fi
}

# --- 실행 ---
echo "design-bounce init: $(pwd)"
if ! ADAPTER=$(detect_adapter); then
  echo "❌ Expo 프로젝트가 아님 (app.json / app.config.js|ts / expo 의존성 없음) — 현재 rn-expo만 지원" >&2
  exit 1
fi
echo "ℹ️  어댑터 감지: $ADAPTER"
gen_config "$ADAPTER"
init_state
if [ "$WRITE" = 1 ]; then merge_settings; else print_snippet; note "settings: 스니펫 출력(미적용)"; fi
doctor

echo
echo "요약: ${SUMMARY[*]}"
if [ "$WRITE" = 1 ] && [ "$FAILED" = 0 ]; then
  echo "다음: 새 세션에서 /design-bounce → 명세 승인 전까지 Write/Edit 차단됨"
  echo "      (게이트를 끄려면 $DB_STATE_FILE 삭제)"
elif [ "$WRITE" = 0 ]; then
  echo "다음: 위 스니펫을 $SETTINGS 에 넣거나 'install.sh init --write' 실행 → 새 세션에서 /design-bounce"
fi
exit "$FAILED"
