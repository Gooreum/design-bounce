#!/usr/bin/env bash
# verdict-summary.sh — verdict.md 요약 헤더 집계 CLI (PreToolUse 훅 아님, 배선 불필요)
#
# steps/step-*/verdict.md 를 번호 순(숫자 정렬)으로 훑어 사이클별 건수,
# 연속 clean 횟수, 편차 추이, 정지조건 판정을 출력한다. step 디렉토리 1개 = 사이클 1개.
#
# 사용법: verdict-summary.sh [state_dir]
#   state_dir 생략 시 lib/state.sh의 DB_STATE_DIR (env DESIGN_BOUNCE_DIR 반영, 기본 .design-bounce)
#
# 출력 예:
#   step-1  blockers=1 high=2 deviations=5  dirty
#   step-2  blockers=0 high=0 deviations=3  clean
#   step-3  blockers=0 high=0 deviations=3  clean
#   consecutive_clean: 2
#   deviation_trend: 5 -> 3 -> 3
#   status: success
#
# 판정 (마지막 줄은 항상 `status: <값>`):
#   none     : verdict.md가 하나도 없음
#   success  : 끝에서부터 연속 clean(blockers=0 && high=0)이 2회 이상
#   plateau  : 최근 3개 verdict가 모두 유효하고 deviations가 줄지 않음
#   continue : 그 외
# 형식이 깨진 verdict는 `invalid`로 표시하고 연속 clean을 0으로 되돌린다.
# 정보 출력용이므로 항상 exit 0 (차단은 screenshot-gate.sh 담당). stuck은 수동 판단.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
. "$HERE/lib/state.sh"
# shellcheck source=lib/verdict.sh
. "$HERE/lib/verdict.sh"

DIR="${1:-$DB_STATE_DIR}"
STEPS_DIR="$DIR/steps"

# verdict.md가 있는 step 번호를 숫자 순으로 수집
NUMS=""
if [ -d "$STEPS_DIR" ]; then
  # bash 3.2는 $( ) 안의 case 파싱이 불안정해 루프 출력을 파이프로 정렬한다
  for d in "$STEPS_DIR"/step-*; do
    n="${d##*/step-}"
    case "$n" in
      ''|*[!0-9]*) continue ;;
    esac
    [ -f "$d/verdict.md" ] && NUMS="$NUMS$n
"
  done
  NUMS=$(printf '%s' "$NUMS" | sort -n)
fi

if [ -z "$NUMS" ]; then
  echo "status: none"
  exit 0
fi

CONSEC=0
TREND=""
# 최근 사이클의 deviations 이력 (invalid는 "x")
DEVS=()
for n in $NUMS; do
  if PARSED=$(db_verdict_parse "$STEPS_DIR/step-$n/verdict.md"); then
    read -r B H _M _N DV <<< "$PARSED"
    if [ "$B" -eq 0 ] && [ "$H" -eq 0 ]; then
      LABEL="clean"; CONSEC=$((CONSEC + 1))
    else
      LABEL="dirty"; CONSEC=0
    fi
    echo "step-$n  blockers=$B high=$H deviations=$DV  $LABEL"
    DEVS+=("$DV")
  else
    echo "step-$n  invalid"
    CONSEC=0
    DV="?"
    DEVS+=("x")
  fi
  TREND="${TREND:+$TREND -> }$DV"
done

echo "consecutive_clean: $CONSEC"
echo "deviation_trend: $TREND"

STATUS="continue"
if [ "$CONSEC" -ge 2 ]; then
  STATUS="success"
elif [ "${#DEVS[@]}" -ge 3 ]; then
  LEN=${#DEVS[@]}
  D1="${DEVS[$((LEN - 3))]}" D2="${DEVS[$((LEN - 2))]}" D3="${DEVS[$((LEN - 1))]}"
  if [ "$D1" != "x" ] && [ "$D2" != "x" ] && [ "$D3" != "x" ] \
     && [ "$D2" -ge "$D1" ] && [ "$D3" -ge "$D2" ]; then
    STATUS="plateau"
  fi
fi

echo "status: $STATUS"
exit 0
