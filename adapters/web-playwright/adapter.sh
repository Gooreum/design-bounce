#!/usr/bin/env bash
# adapter.sh — web-playwright 어댑터 디스패처
# 사용법: adapter.sh <build|launch|navigate|capture> [args...] [--dry-run]
# 첫 인자(fn)로 해당 하위 스크립트를 호출하고 나머지 인자를 그대로 전달한다.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF2'
usage: adapter.sh <fn> [args...]
  fn:
    build                        config.buildCommand 실행 (없으면 생략) → OK
    launch                       dev 서버 기동 후 baseUrl 헬스체크 대기 → OK
    navigate <screen_id>         baseUrl + screens[id].path 도달 확인 → OK
    capture  <screen_id>         Playwright로 viewport 고정 스크린샷 → <png경로>
  옵션:
    --dry-run                    실제 실행 없이 수행할 명령만 출력
EOF2
}

FN="${1:-}"
if [ -z "$FN" ]; then
  usage
  exit 2
fi
shift

case "$FN" in
  build)    exec bash "$HERE/build.sh" "$@" ;;
  launch)   exec bash "$HERE/launch.sh" "$@" ;;
  navigate) exec bash "$HERE/navigate.sh" "$@" ;;
  capture)  exec bash "$HERE/capture.sh" "$@" ;;
  *)
    echo "adapter.sh: 알 수 없는 함수: $FN" >&2
    usage
    exit 2
    ;;
esac
