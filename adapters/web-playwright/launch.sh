#!/usr/bin/env bash
# launch.sh [--dry-run] — dev 서버를 띄우고 baseUrl 헬스체크가 통과할 때까지 대기한다.
# 이미 baseUrl이 응답하면 새로 띄우지 않고 OK.
# 서버는 백그라운드로 남는다: 로그 .design-bounce/web-dev.log, PID .design-bounce/web-dev.pid
# 성공 시 stdout에 `OK`. devCommand 없음+서버 없음 exit 4, 타임아웃 exit 5.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

DRY="${1:-}"
BASE="$(base_url)"
TIMEOUT="$(jq -r '.launchTimeoutMs // 30000' "$CFG")"
LOG="$STATE_DIR/web-dev.log"
PIDF="$STATE_DIR/web-dev.pid"
read_cmd_array devCommand

if [ "$DRY" = "--dry-run" ]; then
  if [ "${#CMD[@]}" -gt 0 ]; then
    echo "START $(print_cmd "${CMD[@]}"); WAIT $BASE ${TIMEOUT}ms"
  else
    echo "WAIT $BASE ${TIMEOUT}ms"
  fi
  exit 0
fi

if health "$BASE"; then
  echo "launch.sh: 이미 실행 중 ($BASE)" >&2
  echo "OK"
  exit 0
fi

if [ "${#CMD[@]}" -eq 0 ]; then
  die 4 "launch.sh: devCommand 또는 실행 중인 서버 필요 ($BASE 응답 없음)"
fi

mkdir -p "$STATE_DIR"
nohup "${CMD[@]}" >"$LOG" 2>&1 &
PID=$!
echo "$PID" > "$PIDF"
echo "launch.sh: dev 서버 기동 pid=$PID log=$LOG" >&2

# 500ms 간격 폴링. 프로세스가 먼저 죽으면 즉시 실패.
TRIES=$(( (TIMEOUT + 499) / 500 ))
i=0
while [ "$i" -lt "$TRIES" ]; do
  if health "$BASE"; then
    echo "OK"
    exit 0
  fi
  if ! kill -0 "$PID" 2>/dev/null; then
    die 5 "launch.sh: dev 서버가 종료됨. 로그 확인: $LOG"
  fi
  sleep 0.5
  i=$((i + 1))
done

die 5 "launch.sh: ${TIMEOUT}ms 내 $BASE 응답 없음. 로그 확인: $LOG"
