#!/usr/bin/env bash
# build.sh [--dry-run] — config.buildCommand(문자열 배열)를 실행한다.
# buildCommand가 없으면 생략하고 OK (dev 서버만 쓰는 프로젝트).
# 성공 시 stdout에 `OK`, 실패 시 exit≠0.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

DRY="${1:-}"
read_cmd_array buildCommand

if [ "${#CMD[@]}" -eq 0 ]; then
  if [ "$DRY" = "--dry-run" ]; then
    echo "SKIP build (buildCommand 없음)"
    exit 0
  fi
  echo "build.sh: buildCommand 없음 → build 생략" >&2
  echo "OK"
  exit 0
fi

if [ "$DRY" = "--dry-run" ]; then
  print_cmd "${CMD[@]}"; echo
  exit 0
fi

"${CMD[@]}" >&2
echo "OK"
