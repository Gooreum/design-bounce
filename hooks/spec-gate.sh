#!/usr/bin/env bash
# spec-gate.sh — PreToolUse(Write|Edit) 훅
#
# design-spec 미승인 상태에서 소스 파일 수정을 차단한다.
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음        → design-bounce 미사용 프로젝트 → 통과(exit 0)
#   - phase="design" & spec_approved!="true" → 차단(block JSON 출력)
#       단, 대상 파일이 state 디렉토리(.design-bounce/) 하위면 통과
#       (명세 저장·state.json 승인 갱신 자체가 막히는 교착 방지)
#   - 그 외                   → 통과
#
# 배선: 채택 프로젝트 .claude/settings.json 의 PreToolUse matcher "Write|Edit".
# 자세한 배선법은 hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

PHASE=$(db_state_field phase "")
APPROVED=$(db_state_field spec_approved "false")

if [ "$PHASE" = "design" ] && [ "$APPROVED" != "true" ]; then
  # stdin(PreToolUse JSON)의 대상 경로가 state 디렉토리 하위면 통과
  INPUT=$(cat)
  FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$FP" in
    *..*) ;;  # 경로 탈출(../) 우회 방지 → 예외 미적용
    */"$DB_STATE_DIR"/*|"$DB_STATE_DIR"/*) exit 0 ;;
  esac
  echo '{"decision":"block","reason":"design-spec 미승인. 명세 승인 후 구현하세요."}'
  exit 0
fi

exit 0
