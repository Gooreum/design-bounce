#!/usr/bin/env bash
# launch.sh [--dry-run] — 부팅된 시뮬레이터에서 앱을 실행한다.
# config의 bundleId를 조회하여 `xcrun simctl launch booted <bundleId>` 실행.
# 성공 시 stdout에 `OK`, 실패 시 exit≠0.
set -euo pipefail

DRY="${1:-}"
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"

BUNDLE_ID="$(jq -r '.bundleId // empty' "$CFG")"
if [ -z "$BUNDLE_ID" ]; then
  echo "launch.sh: config에 bundleId 없음: $CFG" >&2
  exit 4
fi

CMD="xcrun simctl launch booted $BUNDLE_ID"

if [ "$DRY" = "--dry-run" ]; then
  echo "$CMD"
  exit 0
fi

eval "$CMD" >&2
echo "OK"
