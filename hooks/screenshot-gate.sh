#!/usr/bin/env bash
# screenshot-gate.sh — PreToolUse(Write|Edit) 훅
#
# 스크린샷 검증 루프에서 "직전 step의 캡처+판정 아티팩트"가 없으면
# 다음 step의 소스 수정을 차단한다. 판정 없이 계속 코드를 갈아엎는
# self-echo(AI 슬롭) 방지가 목적.
#
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음  → 통과
#   - phase = "review" → 사람 최종 승인 대기. stdin 훅 입력의 file_path가
#     state 디렉토리(.design-bounce/) 아래면 통과(taste.md/state.json 기록),
#     그 외(경로 모름 포함) → 차단
#   - phase != "loop"  → 통과 (루프 밖에서는 강제하지 않음, done 포함)
#   - PREV = current_step - 1 이 1 이상이고
#     steps/step-$PREV/after.png 또는 verdict.md 누락 → 차단
#
# 배선: hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

PHASE=$(db_state_field phase "")
STEP=$(db_state_field current_step "0")

# 사람 최종 승인 대기 중에는 state 디렉토리 밖 수정 차단 (경로 모르면 차단)
if [ "$PHASE" = "review" ]; then
  if ! db_path_in_state_dir "$(db_tool_file_path)"; then
    echo '{"decision":"block","reason":"사람 최종 승인 대기 중. 승인/거부 후 진행."}'
  fi
  exit 0
fi

# 루프 단계가 아니면 강제하지 않음
[ "$PHASE" != "loop" ] && exit 0

PREV=$((STEP - 1))

if [ "$PREV" -ge 1 ]; then
  D="$DB_STATE_DIR/steps/step-$PREV"
  if [ ! -f "$D/after.png" ] || [ ! -f "$D/verdict.md" ]; then
    echo '{"decision":"block","reason":"직전 step 스크린샷/판정 누락. 캡처+판정 후 진행."}'
    exit 0
  fi
fi

exit 0
