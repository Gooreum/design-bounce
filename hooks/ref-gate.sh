#!/usr/bin/env bash
# ref-gate.sh — PreToolUse(Write|Edit) 훅
#
# 「무엇을 보고 만들었나」가 없으면 소스 수정을 차단한다.
#
# 익숙한 물건일수록 찾아보지 않고 만들게 되고, 안 찾아본 물건이 정확히 실패한다.
# 이 훅은 그 습관을 구조로 막는다: 대상마다 실물 이미지 한 장과 「본 것」 메모가
# 남아 있어야 그 대상의 코드를 만질 수 있다.
#
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음                → design-bounce 미사용 프로젝트 → 통과
#   - current_target 이 비어 있음     → 대상 지정 전 → 통과
#   - ref/<대상>/ 에 이미지 1장 없음  → 차단
#   - ref/<대상>/intent.md 없음       → 차단
#   - 둘 다 있음                     → 통과
#
# **이 훅은 내용을 판정하지 않는다. 파일이 있냐 없냐만 본다.**
# 판정을 넣는 순간 구현하는 쪽이 통과 기준을 다시 쓸 수 있게 되고,
# 그러면 게이트가 아니라 자기 채점이 된다.
#
# 배선: hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

TARGET=$(db_state_field current_target "")

# 대상이 정해지기 전에는 강제하지 않는다 (레퍼런스 수집 자체를 막으면 안 된다)
[ -z "$TARGET" ] && exit 0

REF_DIR="$DB_STATE_DIR/ref/$TARGET"

IMG=$(find "$REF_DIR" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        2>/dev/null | head -1)

if [ -z "$IMG" ] || [ ! -f "$REF_DIR/intent.md" ]; then
  printf '{"decision":"block","reason":"%s 의 레퍼런스가 없습니다. .design-bounce/ref/%s/ 에 실물 이미지 1장과 intent.md 를 먼저 남기세요. 아무것도 못 찾았으면 intent.md 에 그렇게 적고 대상을 대기열로 빼세요."}\n' \
    "$TARGET" "$TARGET"
  exit 0
fi

exit 0
