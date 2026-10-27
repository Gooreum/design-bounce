#!/usr/bin/env bash
# capture.sh <screen_id> [--dry-run] — Playwright CLI로 viewport 고정 스크린샷.
# `npx --no-install playwright screenshot --viewport-size=W,H --wait-for-timeout=<settleMs>
#  [--full-page] <url> <captureDir>/<id>.png`
# playwright 로그는 stderr로 돌려 stdout에는 png 경로 한 줄만 남긴다.
# 성공 시 stdout에 png 경로, 실패 시 exit≠0.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

SCREEN="${1:-}"
DRY="${2:-}"
check_screen_id capture.sh "$SCREEN"
URL="$(url_for "$SCREEN")"

OUTDIR="$(jq -r '.captureDir // ".design-bounce/shots"' "$CFG")"
W="$(jq -r '.viewport.width // 1280' "$CFG")"
H="$(jq -r '.viewport.height // 800' "$CFG")"
SETTLE="$(jq -r --arg id "$SCREEN" '.screens[$id].settleMs // 0' "$CFG")"
FULL="$(jq -r --arg id "$SCREEN" '.screens[$id].fullPage // false' "$CFG")"
OUT="$OUTDIR/$SCREEN.png"

CMD=(npx --no-install playwright screenshot
  "--viewport-size=$W,$H" "--wait-for-timeout=$SETTLE")
[ "$FULL" = "true" ] && CMD+=(--full-page)
CMD+=("$URL" "$OUT")

if [ "$DRY" = "--dry-run" ]; then
  print_cmd "${CMD[@]}"; echo
  exit 0
fi

mkdir -p "$OUTDIR"
rm -f "$OUT"
"${CMD[@]}" >&2
[ -s "$OUT" ] || die 1 "capture.sh: 스크린샷 파일 생성 실패: $OUT"
echo "$OUT"
