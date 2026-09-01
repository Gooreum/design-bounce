#!/usr/bin/env bash
# sample-gate.sh — PreToolUse(Write|Edit) 훅
#
# 「샘플 몇 개를 먼저 만들어 그림으로 보이고, 승인받은 다음 전수로 간다」를 강제한다.
#
# 문장으로 된 명세는 항상 맞게 읽힌다. 그래서 문장을 승인받고 전수로 밀면
# 어긋남이 가려진 채 전부에 번지고, 다 만든 뒤에야 드러난다. 이 훅은 그 사이에
# 「실제로 만든 것을 그림으로 보이는」 단계를 끼워 넣고 건너뛰지 못하게 한다.
#
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음                                    → 통과
#   - phase="sample" & targets_done_count >= sample_size → 차단 (시트를 먼저 내라)
#   - phase="bulk"   & sample_approved != "true"         → 차단 (승인 없이 전수 금지)
#   - 그 외                                              → 통과
#
# **이 훅은 결과물을 판정하지 않는다. 개수와 플래그만 본다.**
# 판정을 넣는 순간 구현하는 쪽이 통과 기준을 다시 쓸 수 있게 된다.
#
# 배선: hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

PHASE=$(db_state_field phase "")
APPROVED=$(db_state_field sample_approved "false")
SIZE=$(db_state_field sample_size "5")
DONE=$(db_state_field targets_done_count "0")

# 숫자가 아닌 값이 들어와도 훅이 죽지 않게 한다 — 게이트가 죽으면 그냥 통과가 된다
case "$SIZE" in ''|*[!0-9]*) SIZE=5 ;; esac
case "$DONE" in ''|*[!0-9]*) DONE=0 ;; esac

if [ "$PHASE" = "sample" ] && [ "$DONE" -ge "$SIZE" ]; then
  printf '{"decision":"block","reason":"샘플 %s개를 다 만들었습니다. intent-sheet 로 의도 시트를 뽑아 보내고 승인을 받은 뒤에 이어가세요."}\n' "$SIZE"
  exit 0
fi

if [ "$PHASE" = "bulk" ] && [ "$APPROVED" != "true" ]; then
  echo '{"decision":"block","reason":"샘플 미승인 상태에서 전수 작업은 막습니다. 의도 시트를 보내고 승인받은 뒤 sample_approved 를 true 로 바꾸세요."}'
  exit 0
fi

exit 0
