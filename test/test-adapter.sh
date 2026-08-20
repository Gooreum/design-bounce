#!/usr/bin/env bash
# test-adapter.sh — rn-expo 어댑터 --dry-run 출력 검증
#
# examples/petcycle.config.json을 DESIGN_BOUNCE_CONFIG로 주입하고
# adapter.sh <fn> [args] --dry-run 을 실행하여, 출력에 기대 명령 문자열이
# 포함되는지 assert 한다. 하나라도 FAIL이면 exit 1.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ADAPTER="$REPO/adapters/rn-expo/adapter.sh"
export DESIGN_BOUNCE_CONFIG="$REPO/examples/petcycle.config.json"

PASS=0
FAIL=0

# assert: adapter.sh dry-run 출력에 문자열 포함
#   $1 라벨  $2 기대포함문자열  $3.. adapter.sh 인자
check() {
  local label="$1" expect="$2"; shift 2
  local out ec
  out="$(bash "$ADAPTER" "$@" --dry-run 2>&1)"; ec=$?
  if [ "$ec" -eq 0 ] && printf '%s' "$out" | grep -qF -- "$expect"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    기대 포함: $expect"
    echo "    실제 출력: $out (exit=$ec)"
    FAIL=$((FAIL + 1))
  fi
}

echo "test-adapter: rn-expo --dry-run (config=$DESIGN_BOUNCE_CONFIG)"

check "build → expo run:ios"                   "expo run:ios"                       build
check "launch → simctl launch booted bundleId" "simctl launch booted com.petcycletest.app" launch
check "navigate home → openurl booted deeplink" 'openurl booted "petcycle://home"'  navigate home
check "capture home → simctl io screenshot"    "simctl io booted screenshot"        capture home

echo "-----------------------------------------"
echo "test-adapter PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
