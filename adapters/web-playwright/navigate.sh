#!/usr/bin/env bash
# navigate.sh <screen_id> [--dry-run] — baseUrl + screens[id].path 도달 가능 여부 확인.
# 호출마다 프로세스가 따로 떠서 브라우저 상태가 유지되지 않으므로 실제 이동은
# capture가 자기완결로 수행한다. navigate는 "도달 확인"만 맡는다.
# 성공 시 stdout에 `OK`. path 없음/상대경로/응답 실패 exit 3.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

SCREEN="${1:-}"
DRY="${2:-}"
check_screen_id navigate.sh "$SCREEN"
URL="$(url_for "$SCREEN")"

if [ "$DRY" = "--dry-run" ]; then
  echo "CHECK $URL"
  exit 0
fi

health "$URL" || die 3 "navigate.sh: 응답 없음: $URL"
echo "OK"
