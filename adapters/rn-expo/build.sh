#!/usr/bin/env bash
# build.sh [--dry-run] — RN/Expo 앱을 빌드하여 부팅된 iOS 시뮬레이터에 설치한다.
# 성공 시 stdout에 `OK`, 실패 시 exit≠0.
set -euo pipefail

DRY="${1:-}"
CMD="npx expo run:ios"

if [ "$DRY" = "--dry-run" ]; then
  echo "$CMD"
  exit 0
fi

eval "$CMD" >&2
echo "OK"
