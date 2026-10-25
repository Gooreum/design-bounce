#!/usr/bin/env bash
# navigate.sh <screen_id> [--dry-run] — 딥링크로 화면 이동.
# config의 .screens[<id>].deeplink를 조회하여
# `xcrun simctl openurl booted "<deeplink>"` 실행.
# 성공 시 stdout에 `OK`, 실패 시 exit≠0. 딥링크 없으면 exit 3.
set -euo pipefail

SCREEN="${1:-}"
DRY="${2:-}"
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"

if [ -z "$SCREEN" ]; then
  echo "navigate.sh: screen_id 인자 필요" >&2
  exit 2
fi
# 경로 탐색(../) 방지: screen_id는 [A-Za-z0-9_-]+ 만 허용
if ! [[ "$SCREEN" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "navigate.sh: 잘못된 screen_id (허용: [A-Za-z0-9_-]+): $SCREEN" >&2
  exit 2
fi

DEEPLINK="$(jq -r --arg id "$SCREEN" '.screens[$id].deeplink // empty' "$CFG")"
if [ -z "$DEEPLINK" ]; then
  echo "deeplink 미정: Maestro flow 필요 (screen=$SCREEN)" >&2
  exit 3
fi

CMD=(xcrun simctl openurl booted "$DEEPLINK")

if [ "$DRY" = "--dry-run" ]; then
  printf '%q ' "${CMD[@]}"; echo
  exit 0
fi

"${CMD[@]}" >&2
echo "OK"
