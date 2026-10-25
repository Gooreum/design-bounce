#!/usr/bin/env bash
# screenshot-gate.sh — PreToolUse(Write|Edit) 훅
#
# 스크린샷 검증 루프에서 "직전 step의 캡처+판정 아티팩트"가 없으면
# 다음 step의 소스 수정을 차단한다. 판정 없이 계속 코드를 갈아엎는
# self-echo(AI 슬롭) 방지가 목적.
#
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다:
#   - state 파일 없음  → 통과
#   - phase != "loop"  → 통과 (루프 밖에서는 강제하지 않음)
#   - PREV = current_step - 1 이 1 이상이고
#     steps/step-$PREV/after.png 또는 verdict.md 누락 → 차단
#   - verdict.md 형식 위반 → 차단 (사유에 step·누락 항목·템플릿 경로 안내)
#       · 첫 줄 요약 헤더(blockers/high/medium/nit/deviations) 없음·형식 오류·빈 파일
#       · 필수 섹션(잘된 점/트랙 A/트랙 B/정지 판단) 누락
#     형식 계약: knowledge/verdict-template.md
#
# 배선: hooks/install.md 참고.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"
# shellcheck source=lib/verdict.sh
. "$HERE/lib/verdict.sh"

# design-bounce 미사용 → 통과
db_state_exists || exit 0

PHASE=$(db_state_field phase "")
STEP=$(db_state_field current_step "0")

# 루프 단계가 아니면 강제하지 않음
[ "$PHASE" != "loop" ] && exit 0

PREV=$((STEP - 1))

if [ "$PREV" -ge 1 ]; then
  D="$DB_STATE_DIR/steps/step-$PREV"
  if [ ! -f "$D/after.png" ] || [ ! -f "$D/verdict.md" ]; then
    echo '{"decision":"block","reason":"직전 step 스크린샷/판정 누락. 캡처+판정 후 진행."}'
    exit 0
  fi

  # verdict.md 형식 검사 (reason에 큰따옴표 금지 — JSON 깨짐 방지)
  TEMPLATE="knowledge/verdict-template.md"
  if ! db_verdict_parse "$D/verdict.md" >/dev/null; then
    echo "{\"decision\":\"block\",\"reason\":\"step-$PREV verdict.md 형식 오류: 첫 줄 요약 헤더 없음 (blockers: N, high: N, medium: N, nit: N, deviations: N). $TEMPLATE 참고.\"}"
    exit 0
  fi
  MISSING=$(db_verdict_missing_sections "$D/verdict.md" | paste -sd ',' - | sed 's/,/, /g')
  if [ -n "$MISSING" ]; then
    echo "{\"decision\":\"block\",\"reason\":\"step-$PREV verdict.md 형식 오류: 필수 섹션 누락 ($MISSING). $TEMPLATE 참고.\"}"
    exit 0
  fi
fi

exit 0
