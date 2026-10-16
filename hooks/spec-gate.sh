#!/usr/bin/env bash
# spec-gate.sh — PreToolUse(Write|Edit) 훅
#
# design-spec 미승인 상태에서 소스 파일 수정을 차단한다.
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음        → design-bounce 미사용 프로젝트 → 통과(exit 0)
#   - 대상 경로가 state 디렉토리($DB_STATE_DIR) 아래 → 통과
#     (Design Phase에서 design-spec.md 저장 / state.json 갱신을 허용)
#   - phase="design" & spec_approved!="true" → 차단(block JSON 출력)
#   - 그 외                   → 통과
#
# 배선: 채택 프로젝트 .claude/settings.json 의 PreToolUse matcher "Write|Edit".
# 자세한 배선법은 hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

# PreToolUse stdin JSON의 tool_input.file_path가 state 디렉토리 아래면 통과.
# stdin 없음/파싱 실패 → 경로 미상으로 보고 기존 판정을 따른다.
db_target_in_state_dir() {
  local input fp dir sd dir_phys
  [ -t 0 ] && return 1
  input=$(cat) || return 1
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || return 1
  [ -n "$fp" ] || return 1
  # .. 세그먼트로 state 디렉토리를 빠져나가는 경로는 허용하지 않음
  case "/$fp/" in */../*) return 1 ;; esac
  sd=$(cd -P "$DB_STATE_DIR" 2>/dev/null && pwd) || return 1
  # 아직 없는 하위 디렉토리(steps/step-N 등)는 가장 가까운 기존 상위로 판정
  dir=$(dirname "$fp")
  while [ ! -d "$dir" ]; do dir=$(dirname "$dir"); done
  # 물리 경로로 비교 (상대/절대, /var ↔ /private/var 심링크 차이 흡수)
  dir_phys=$(cd -P "$dir" 2>/dev/null && pwd) || return 1
  case "$dir_phys/" in "$sd"/*) return 0 ;; esac
  return 1
}

PHASE=$(db_state_field phase "")
APPROVED=$(db_state_field spec_approved "false")

if [ "$PHASE" = "design" ] && [ "$APPROVED" != "true" ]; then
  db_target_in_state_dir && exit 0
  echo '{"decision":"block","reason":"design-spec 미승인. 명세 승인 후 구현하세요."}'
  exit 0
fi

exit 0
