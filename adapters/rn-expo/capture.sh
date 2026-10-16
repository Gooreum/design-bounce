#!/usr/bin/env bash
# capture.sh <screen_id> [--dry-run] — 부팅된 시뮬레이터에서 스크린샷 캡처.
# config의 captureDir/settleMs를 조회하여 settle 대기 후
# `xcrun simctl io booted screenshot "<captureDir>/<id>.png"` 실행.
# 성공 시 stdout에 png 경로, 실패 시 exit≠0.
set -euo pipefail

SCREEN="${1:-}"
DRY="${2:-}"
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"

if [ -z "$SCREEN" ]; then
  echo "capture.sh: screen_id 인자 필요" >&2
  exit 2
fi
# 경로 탐색(../) 방지: screen_id는 [A-Za-z0-9_-]+ 만 허용
if ! [[ "$SCREEN" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "capture.sh: 잘못된 screen_id (허용: [A-Za-z0-9_-]+): $SCREEN" >&2
  exit 2
fi

OUTDIR="$(jq -r '.captureDir // ".design-bounce/shots"' "$CFG")"
SETTLE="$(jq -r --arg id "$SCREEN" '.screens[$id].settleMs // 0' "$CFG")"
OUT="$OUTDIR/$SCREEN.png"
CMD=(xcrun simctl io booted screenshot "$OUT")

if [ "$DRY" = "--dry-run" ]; then
  printf 'SLEEP %sms; ' "$SETTLE"; printf '%q ' "${CMD[@]}"; echo
  exit 0
fi

mkdir -p "$OUTDIR"
if [ "$SETTLE" -gt 0 ]; then
  sleep "$(echo "scale=3; $SETTLE/1000" | bc -l)"
fi
"${CMD[@]}" >&2
echo "$OUT"
