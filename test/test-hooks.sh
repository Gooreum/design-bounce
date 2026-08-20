#!/usr/bin/env bash
# test-hooks.sh — spec-gate.sh / screenshot-gate.sh 유닛테스트
#
# 각 케이스마다 임시 state 디렉토리(mktemp -d)를 만들고 DESIGN_BOUNCE_DIR로
# 지정한 뒤 훅을 실행하여 stdout/exit code를 assert 한다.
# 하나라도 FAIL이면 exit 1.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SPEC_GATE="$REPO/hooks/spec-gate.sh"
SHOT_GATE="$REPO/hooks/screenshot-gate.sh"
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
printf '# verdict\npass\n' > "$SD/steps/step-1/verdict.md"
OUT=$(DESIGN_BOUNCE_DIR="$SD" bash "$SHOT_GATE"); EC=$?
check "screenshot-gate: step-1 아티팩트 있음 → 통과" 0 "" "$EC" "$OUT"

# ---------------------------------------------------------------------------
# 결과 집계
# ---------------------------------------------------------------------------
echo "-----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
