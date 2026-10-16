#!/usr/bin/env bash
set -euo pipefail
# test-install.sh — install.sh 유닛테스트
#
# CLAUDE_SKILLS_DIR를 임시 디렉토리로 override 하여 실제 ~/.claude/skills를
# 건드리지 않고 설치 동작을 검증한다. 8개 케이스:
#   1) 신규 설치 → 심링크 생성
#   2) SKILL.md 해석 (심링크 통해 파일 접근)
#   3) idempotent 재설치 → exit 0
#   4) --help → exit 0
#   5) 알 수 없는 인자 → exit≠0
#   6) --version 출력 (임시 git 레포)
#   7) --update 비-git 거부 → exit≠0
#   8) --update upstream 미설정 → 안내 후 exit 0
#   init (임시 Expo 프로젝트 $TMP/proj):
#   9) config 생성 + scheme 추출       10) state.json phase=design, spec_approved=false
#  11) state 재실행 보존                12) config 재실행 보존
#  13) --write 2회 멱등 + permissions 보존
#  14) 배선된 spec-gate command 가 소스 Write 차단
#  15) Expo 아닌 디렉토리 → exit≠0      16) init은 CLAUDE_SKILLS_DIR 미생성
# --version/--update는 DESIGN_BOUNCE_GIT_DIR를 override 하므로 실제 레포에
# git pull/fetch가 일어나지 않는다 (임시 레포는 upstream 없음, 네트워크 불필요).

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() {
  # $1 라벨  $2 평가할 표현식(문자열)
  if eval "$2"; then
    echo "  PASS: $1"; pass=$((pass+1))
  else
    echo "  FAIL: $1"; fail=$((fail+1))
  fi
}

# 1) 신규 설치 → 심링크 생성 + SKILL.md 해석 + exit 0
CLAUDE_SKILLS_DIR="$TMP/skills" bash "$REPO/install.sh" >/dev/null
check "심링크 생성"     "[ -L '$TMP/skills/design-bounce' ]"
check "SKILL.md 해석"   "[ -f '$TMP/skills/design-bounce/SKILL.md' ]"

# 2) 재실행 idempotent → exit 0
check "idempotent 재설치" "CLAUDE_SKILLS_DIR='$TMP/skills' bash '$REPO/install.sh' >/dev/null 2>&1"

# 3) --help → exit 0
check "--help exit 0" "bash '$REPO/install.sh' --help >/dev/null 2>&1"

# 4) 알 수 없는 인자 → exit≠0
check "unknown arg 거부" "! bash '$REPO/install.sh' --bogus >/dev/null 2>&1"

# 임시 git 레포 픽스처 (upstream 없음)
GITREPO="$TMP/gitrepo"; mkdir -p "$GITREPO"
( cd "$GITREPO" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init ) 2>/dev/null
# 6) --version: git 대상 override → exit 0 + "design-bounce" 출력
#    (출력을 먼저 캡처 후 grep — pipefail 하에서 grep -q의 SIGPIPE 회피)
check "--version 출력" "out=\$(DESIGN_BOUNCE_GIT_DIR='$GITREPO' bash '$REPO/install.sh' --version 2>/dev/null); echo \"\$out\" | grep -q design-bounce"
# 7) --update: 비-git 디렉토리 → exit 1
check "--update 비-git 거부" "! DESIGN_BOUNCE_GIT_DIR='$TMP' bash '$REPO/install.sh' --update >/dev/null 2>&1"
# 8) --update: upstream 미설정 → 안내 후 exit 0
check "--update upstream 미설정" "out=\$(DESIGN_BOUNCE_GIT_DIR='$GITREPO' bash '$REPO/install.sh' --update 2>/dev/null); echo \"\$out\" | grep -q upstream"

# --- init ---
PROJ="$TMP/proj"; mkdir -p "$PROJ/.claude"
echo '{"expo":{"scheme":"demo","ios":{"bundleIdentifier":"com.demo"}}}' > "$PROJ/app.json"
echo '{"permissions":{"allow":["Bash(ls)"]}}' > "$PROJ/.claude/settings.json"
INIT_SKILLS="$TMP/init-skills"
init() { ( cd "$PROJ" && CLAUDE_SKILLS_DIR="$INIT_SKILLS" bash "$REPO/install.sh" init "$@" ) >/dev/null 2>&1; }
CFGF="$PROJ/design-bounce.config.json"; STF="$PROJ/.design-bounce/state.json"

init
check "init: config 생성 + scheme"   "[ \"\$(jq -r .scheme '$CFGF')\" = demo ]"
check "init: state phase=design"      "[ \"\$(jq -r .phase '$STF')\" = design ] && [ \"\$(jq -r .spec_approved '$STF')\" = false ]"
# 11~12) 재실행 시 기존 state/config 보존
jq '.phase = "loop"' "$STF" > "$STF.tmp" && mv "$STF.tmp" "$STF"
jq '.marker = 1' "$CFGF" > "$CFGF.tmp" && mv "$CFGF.tmp" "$CFGF"
init
check "init: state 보존"   "[ \"\$(jq -r .phase '$STF')\" = loop ]"
check "init: config 보존"  "[ \"\$(jq -r .marker '$CFGF')\" = 1 ]"
# 13) --write 2회 → spec-gate command 1개 + 기존 permissions 보존
init --write; init --write
SET="$PROJ/.claude/settings.json"
check "init --write 멱등" "[ \"\$(jq '[.hooks.PreToolUse[].hooks[].command | select(endswith(\"spec-gate.sh\"))] | length' '$SET')\" = 1 ]"
check "init --write permissions 보존" "jq -e '.permissions.allow[0] == \"Bash(ls)\"' '$SET' >/dev/null"
# 14) design 미승인 → 배선된 spec-gate command 로 소스 Write 시 block
jq '.phase = "design" | .spec_approved = false' "$STF" > "$STF.tmp" && mv "$STF.tmp" "$STF"
GATE_CMD=$(jq -r '[.hooks.PreToolUse[].hooks[].command | select(endswith("spec-gate.sh"))][0]' "$SET")
check "init: 배선된 spec-gate 차단" "out=\$(cd '$PROJ' && echo '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"app/x.tsx\"}}' | bash -c \"\$GATE_CMD\"); echo \"\$out\" | grep -q block"
# 15) Expo 아닌 디렉토리 → exit≠0
mkdir -p "$TMP/notexpo"
check "init: Expo 아님 거부" "! ( cd '$TMP/notexpo' && bash '$REPO/install.sh' init ) >/dev/null 2>&1"
# 16) init은 스킬 설치 단계를 실행하지 않음
check "init: 스킬 설치 미실행" "[ ! -e '$INIT_SKILLS' ]"

echo "test-install PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
