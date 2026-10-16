#!/usr/bin/env bash
# test-measure.sh — scripts/measure.sh 유닛테스트
#
# 각 케이스마다 임시 프로젝트 디렉토리(mktemp -d)에 config/토큰 fixture를 두고
# 그 안에서 measure.sh를 실행한 뒤, exit code와 jq로 읽은 measure.json 필드를 assert 한다.
# 하나라도 FAIL이면 exit 1.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
MEASURE="$REPO/scripts/measure.sh"
FIXTURES="$HERE/fixtures"

PASS=0
FAIL=0
TMPDIRS=()

cleanup() {
  local d
  for d in "${TMPDIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

# 새 임시 프로젝트 디렉토리 생성 → 경로 출력
#   $1 토큰 fixture 파일 ("" 이면 토큰 파일 없음)
new_project() {
  local d
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  cp "$FIXTURES/measure.config.json" "$d/design-bounce.config.json"
  [ -n "$1" ] && cp "$1" "$d/tokens.json"
  printf '%s' "$d"
}

# measure.sh 실행 → EC 설정, M 에 measure.json 경로
#   $1 프로젝트 디렉토리  $2 step  (env DESIGN_BOUNCE_DIR 그대로 전달)
run_measure() {
  (cd "$1" && bash "$MEASURE" --step "$2" >/dev/null 2>&1); EC=$?
  M="$1/${DESIGN_BOUNCE_DIR:-.design-bounce}/steps/step-$2/measure.json"
}

# assert: jq 식이 true + exit code 일치
#   $1 라벨  $2 기대exit  $3 실제exit  $4 measure.json  $5 jq 식
check() {
  local label="$1" exp_exit="$2" act_exit="$3" file="$4" expr="$5"
  local ok=1
  [ "$act_exit" -eq "$exp_exit" ] || ok=0
  [ "$(jq -r "$expr" "$file" 2>/dev/null)" = "true" ] || ok=0
  if [ "$ok" -eq 1 ]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "      기대 exit=$exp_exit, 실제 exit=$act_exit, 식='$expr'"
    [ -f "$file" ] && cat "$file"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# TC-1: measure 미설정 → skipped, exit 0
P=$(new_project "")
jq 'del(.measure)' "$P/design-bounce.config.json" > "$P/c.json" && mv "$P/c.json" "$P/design-bounce.config.json"
run_measure "$P" 1
check "measure 미설정 → skipped" 0 "$EC" "$M" '.status == "skipped" and .reason == "measure 미설정"'

# TC-2: 토큰 파일 없음 → error, exit 2
P=$(new_project "")
run_measure "$P" 1
check "토큰 파일 없음 → error" 2 "$EC" "$M" '.status == "error" and (.reason | startswith("토큰 파일 없음"))'

# TC-3: pass fixture → pass, 위반 0, exit 0
P=$(new_project "$FIXTURES/tokens-pass.json")
run_measure "$P" 1
check "pass fixture → status=pass" 0 "$EC" "$M" \
  '.status == "pass" and (.violations | length) == 0 and .summary.contrast.checked == 4 and .summary.grid.checked == 6'
check "#767676 on #FFFFFF (4.54) → 통과" 0 "$EC" "$M" \
  '[.violations[] | select(.target == "colors.textMuted on colors.bg")] | length == 0'

# TC-4~7: fail fixture
P=$(new_project "$FIXTURES/tokens-fail.json")
run_measure "$P" 3
check "fail fixture → status=fail, exit 1" 1 "$EC" "$M" '.status == "fail" and .step == 3'
check "대비 위반 1건 (textMuted, < 4.5, Blocker)" 1 "$EC" "$M" \
  '[.violations[] | select(.rule == "wcag-contrast")] as $c
   | ($c | length) == 1 and $c[0].target == "colors.textMuted on colors.bg"
     and $c[0].measured < 4.5 and $c[0].required == 4.5 and $c[0].severity == "Blocker"'
check "그리드 위반 2건 (13, 17px)" 1 "$EC" "$M" \
  '[.violations[] | select(.rule == "spacing-grid") | .measured] == [13, 17]'
check "#RRGGBBAA → skipped" 1 "$EC" "$M" \
  '[.skipped[] | select(.target == "colors.overlay on colors.bg" and (.reason | contains("#00000080")))] | length == 1'
check "large 쌍 (3.0~4.5) → 위반 아님" 1 "$EC" "$M" \
  '[.violations[] | select(.target == "colors.heading on colors.bg")] | length == 0'
check "radius 는 info 만 기록" 1 "$EC" "$M" '.info.radiusDistinct == [4, 6, 12]'

# TC-8: 4.5 경계 — #777777 on #FFFFFF (4.48) 은 반올림 없이 위반
P=$(new_project "")
printf '{"colors":{"fg":"#777777","bg":"#FFFFFF"}}' > "$P/tokens.json"
jq '.measure.colorPairs = [{"fg":"colors.fg","bg":"colors.bg"}]' "$P/design-bounce.config.json" > "$P/c.json" \
  && mv "$P/c.json" "$P/design-bounce.config.json"
run_measure "$P" 1
check "#777777 on #FFFFFF → 위반 (4.47 < 4.5)" 1 "$EC" "$M" '.violations[0].measured == 4.47'

# TC-9: DESIGN_BOUNCE_DIR override 경로에 생성
P=$(new_project "$FIXTURES/tokens-pass.json")
DESIGN_BOUNCE_DIR="custom-state" run_measure "$P" 2
check "DESIGN_BOUNCE_DIR override" 0 "$EC" "$P/custom-state/steps/step-2/measure.json" '.status == "pass"'

# TC-10: --step 누락 → exit 2
OUT=$(bash "$MEASURE" 2>&1); EC=$?
if [ "$EC" -eq 2 ]; then
  echo "PASS: --step 누락 → exit 2"; PASS=$((PASS + 1))
else
  echo "FAIL: --step 누락 → exit 2 (실제 exit=$EC, out='$OUT')"; FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# 결과 집계
# ---------------------------------------------------------------------------
echo "-----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
