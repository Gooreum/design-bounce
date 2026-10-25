#!/usr/bin/env bash
# test-hooks.sh — spec-gate.sh / screenshot-gate.sh / verdict-summary.sh 유닛테스트
#
# 각 케이스마다 임시 state 디렉토리(mktemp -d)를 만들고 DESIGN_BOUNCE_DIR로
# 지정한 뒤 훅을 실행하여 stdout/exit code를 assert 한다.
# 하나라도 FAIL이면 exit 1.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SPEC_GATE="$REPO/hooks/spec-gate.sh"
SHOT_GATE="$REPO/hooks/screenshot-gate.sh"
SUMMARY="$REPO/hooks/verdict-summary.sh"
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

# 새 임시 state 디렉토리 생성 → 경로 출력
new_state_dir() {
  local d
  d=$(mktemp -d)
  TMPDIRS+=("$d")
  printf '%s' "$d/.design-bounce"
}

# assert: 출력에 문자열 포함 + exit code 일치
#   $1 라벨  $2 기대exit  $3 기대포함문자열("" 이면 무출력 기대)  $4 실제exit  $5 실제출력
check() {
  local label="$1" exp_exit="$2" exp_sub="$3" act_exit="$4" act_out="$5"
  local ok=1
  [ "$act_exit" -eq "$exp_exit" ] || ok=0
  if [ -z "$exp_sub" ]; then
    [ -z "$act_out" ] || ok=0
  else
    case "$act_out" in
      *"$exp_sub"*) : ;;
      *) ok=0 ;;
    esac
  fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "      기대 exit=$exp_exit, sub='${exp_sub}'"
    echo "      실제 exit=$act_exit, out='${act_out}'"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# spec-gate 케이스
# ---------------------------------------------------------------------------

# TC-1: phase=design & spec_approved=false → block
SD=$(new_state_dir); mkdir -p "$SD"
cp "$FIXTURES/state-design-unapproved.json" "$SD/state.json"
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SPEC_GATE"); EC=$?
check "spec-gate: design 미승인 → block" 0 '"decision":"block"' "$EC" "$OUT"

# TC-2: phase=design & spec_approved=true → 통과(무출력, exit0)
SD=$(new_state_dir); mkdir -p "$SD"
cp "$FIXTURES/state-design-approved.json" "$SD/state.json"
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SPEC_GATE"); EC=$?
check "spec-gate: design 승인 → 통과" 0 "" "$EC" "$OUT"

# TC-3: state 파일 없음 → 통과(무출력, exit0)
SD=$(new_state_dir); mkdir -p "$SD"   # state.json 생성 안 함
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SPEC_GATE"); EC=$?
check "spec-gate: state 없음 → 통과" 0 "" "$EC" "$OUT"

# ---------------------------------------------------------------------------
# screenshot-gate 케이스
# ---------------------------------------------------------------------------

# TC-4: phase=loop, current_step=2, step-1 아티팩트 없음 → block
SD=$(new_state_dir); mkdir -p "$SD"
cp "$FIXTURES/state-loop-step2.json" "$SD/state.json"
# steps/step-1 디렉토리 자체를 만들지 않음 → 아티팩트 누락
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: step-1 아티팩트 없음 → block" 0 '"decision":"block"' "$EC" "$OUT"

# TC-5: phase=loop, current_step=2, step-1/after.png + verdict.md 존재 → 통과
SD=$(new_state_dir); mkdir -p "$SD/steps/step-1"
cp "$FIXTURES/state-loop-step2.json" "$SD/state.json"
printf 'PNG' > "$SD/steps/step-1/after.png"
cp "$FIXTURES/verdicts/valid.md" "$SD/steps/step-1/verdict.md"
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: step-1 아티팩트 있음 → 통과" 0 "" "$EC" "$OUT"

# loop/step2 state + step-1/after.png 를 만들고 verdict.md 를 $1 내용으로 채운 state 디렉토리 출력
loop_with_verdict() {
  local sd
  sd=$(new_state_dir); mkdir -p "$sd/steps/step-1"
  cp "$FIXTURES/state-loop-step2.json" "$sd/state.json"
  printf 'PNG' > "$sd/steps/step-1/after.png"
  cp "$1" "$sd/steps/step-1/verdict.md"
  printf '%s' "$sd"
}

# TC-6: 요약 헤더 없는 verdict → block + 사유 안내
SD=$(loop_with_verdict "$FIXTURES/verdicts/no-header.md")
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: 헤더 없는 verdict → block" 0 '"decision":"block"' "$EC" "$OUT"
check "screenshot-gate: 헤더 없음 사유 안내" 0 '요약 헤더' "$EC" "$OUT"
check "screenshot-gate: 차단 출력이 유효한 JSON" 0 'block' "$EC" "$(printf '%s' "$OUT" | jq -r .decision 2>&1)"

# TC-7: 빈 verdict → block
SD=$(loop_with_verdict "$FIXTURES/verdicts/empty.md")
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: 빈 verdict → block" 0 '"decision":"block"' "$EC" "$OUT"

# TC-8: 헤더는 있고 섹션 누락 → block + 누락 섹션 이름
SD=$(loop_with_verdict "$FIXTURES/verdicts/missing-section.md")
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: 섹션 누락 verdict → block" 0 '"decision":"block"' "$EC" "$OUT"
check "screenshot-gate: 누락 섹션 이름 안내" 0 '트랙 B' "$EC" "$OUT"

# TC-9: 헤더가 첫 줄이 아니라 본문 중간 → block
TMPV="$(dirname "$(new_state_dir)")/verdict.md"
{ echo "# verdict"; cat "$FIXTURES/verdicts/valid.md"; } > "$TMPV"
SD=$(loop_with_verdict "$TMPV")
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: 헤더가 첫 줄 아님 → block" 0 '요약 헤더' "$EC" "$OUT"

# ---------------------------------------------------------------------------
# verdict-summary 케이스
# ---------------------------------------------------------------------------

# TC-10: dirty → clean → clean → success
OUT=$(bash "$SUMMARY" "$FIXTURES/steps-success"); EC=$?
check "verdict-summary: 연속 clean 2회" 0 'consecutive_clean: 2' "$EC" "$OUT"
check "verdict-summary: success 판정" 0 'status: success' "$EC" "$OUT"

# TC-11: deviations 3 → 3 → 3 → plateau
OUT=$(bash "$SUMMARY" "$FIXTURES/steps-plateau"); EC=$?
check "verdict-summary: 편차 추이" 0 'deviation_trend: 3 -> 3 -> 3' "$EC" "$OUT"
check "verdict-summary: plateau 판정" 0 'status: plateau' "$EC" "$OUT"

# TC-12: steps 없음 → none, exit 0 (인자 생략 시 DESIGN_BOUNCE_DIR 사용)
SD=$(new_state_dir); mkdir -p "$SD"
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SUMMARY"); EC=$?
check "verdict-summary: steps 없음 → none" 0 'status: none' "$EC" "$OUT"

# TC-13: step-1, step-2, step-10 → 숫자 순 정렬
SD=$(new_state_dir)
for n in 1 2 10; do
  mkdir -p "$SD/steps/step-$n"
  cp "$FIXTURES/verdicts/valid.md" "$SD/steps/step-$n/verdict.md"
done
OUT=$(bash "$SUMMARY" "$SD"); EC=$?
ORDER=$(printf '%s\n' "$OUT" | grep -o '^step-[0-9]*' | tr '\n' ' ')
check "verdict-summary: 숫자 정렬 1→2→10" 0 'step-1 step-2 step-10 ' "$EC" "$ORDER"

# TC-14: 형식 깨진 step → invalid, 연속 clean 리셋
cp "$FIXTURES/verdicts/no-header.md" "$SD/steps/step-10/verdict.md"
OUT=$(bash "$SUMMARY" "$SD"); EC=$?
check "verdict-summary: invalid 표시" 0 'step-10  invalid' "$EC" "$OUT"
check "verdict-summary: invalid 후 연속 clean 0" 0 'consecutive_clean: 0' "$EC" "$OUT"

# ---------------------------------------------------------------------------
# 결과 집계
# ---------------------------------------------------------------------------
echo "-----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
