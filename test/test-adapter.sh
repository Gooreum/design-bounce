#!/usr/bin/env bash
# test-adapter.sh — 어댑터 --dry-run 출력 검증
#
# 어댑터별 example config를 DESIGN_BOUNCE_CONFIG로 주입하고
# adapter.sh <fn> [args] --dry-run 을 실행하여, 출력에 기대 명령 문자열이
# 포함되는지 assert 한다. 음성 케이스는 기대 exit 코드를 assert 한다.
# 하나라도 FAIL이면 exit 1.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
FIX="$HERE/fixtures"

PASS=0
FAIL=0

# assert: adapter.sh dry-run 출력에 문자열 포함
#   $1 라벨  $2 기대포함문자열  $3.. adapter.sh 인자
# 사용할 어댑터/config는 ADAPTER / DESIGN_BOUNCE_CONFIG 로 지정.
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

# assert: adapter.sh 실행 exit 코드
#   $1 라벨  $2 기대 exit  $3.. adapter.sh 인자
check_exit() {
  local label="$1" want="$2"; shift 2
  local out ec
  out="$(bash "$ADAPTER" "$@" 2>&1)"; ec=$?
  if [ "$ec" -eq "$want" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    기대 exit: $want"
    echo "    실제 출력: $out (exit=$ec)"
    FAIL=$((FAIL + 1))
  fi
}

# --- rn-expo ---------------------------------------------------------------
ADAPTER="$REPO/adapters/rn-expo/adapter.sh"
export DESIGN_BOUNCE_CONFIG="$REPO/examples/petcycle.config.json"
echo "test-adapter: rn-expo --dry-run (config=$DESIGN_BOUNCE_CONFIG)"

check "build → expo run:ios"                   "expo run:ios"                       build
check "launch → simctl launch booted bundleId" "simctl launch booted com.petcycletest.app" launch
check "navigate home → openurl booted deeplink" 'openurl booted "petcycle://home"'  navigate home
check "capture home → simctl io screenshot"    "simctl io booted screenshot"        capture home

# --- web-playwright --------------------------------------------------------
ADAPTER="$REPO/adapters/web-playwright/adapter.sh"
export DESIGN_BOUNCE_CONFIG="$REPO/examples/web.config.json"
echo "test-adapter: web-playwright --dry-run (config=$DESIGN_BOUNCE_CONFIG)"

check "build → npm run build"          "npm run build"                                  build
check "launch → START devCommand; WAIT baseUrl" \
  "START npm run dev -- --port 5173 --strictPort; WAIT http://localhost:5173 30000ms"  launch
check "navigate home → CHECK baseUrl/" "CHECK http://localhost:5173/"                  navigate home
check "capture home → playwright screenshot viewport" \
  "npx --no-install playwright screenshot --viewport-size=1280,800 --wait-for-timeout=600 http://localhost:5173/ .design-bounce/shots/home.png" \
  capture home
check "capture pricing → --full-page"  "--full-page http://localhost:5173/pricing"     capture pricing
check_exit "capture 인자 누락 → exit 2"           2 capture
check_exit "capture ../x screen_id → exit 2"      2 capture ../x --dry-run

# web-bad-path의 baseUrl은 discard 포트(9)라 응답하는 서버가 없다.
export DESIGN_BOUNCE_CONFIG="$FIX/web-bad-path.config.json"
check_exit "navigate path 없음 → exit 3"          3 navigate nopath --dry-run
check_exit "navigate 상대 path → exit 3"          3 navigate relative --dry-run
check_exit "capture //host path → exit 3"         3 capture protocolRelative --dry-run
check      "build buildCommand 없음 → SKIP"       "SKIP build"                     build
check_exit "launch devCommand 없음+서버 없음 → exit 4" 4 launch

# 주입 방지: buildCommand 원소의 `;`·`$()`가 셸에 해석되지 않아야 한다.
export DESIGN_BOUNCE_CONFIG="$FIX/web-injection.config.json"
PWNED=/tmp/design-bounce-pwned
rm -f "$PWNED"
check_exit "build 주입 문자열 실행 → exit 0"      0 build
if [ ! -e "$PWNED" ]; then
  echo "  PASS: build 주입 문자열이 셸에 해석되지 않음"
  PASS=$((PASS + 1))
else
  echo "  FAIL: build 주입 문자열이 실행됨 ($PWNED 생성)"
  FAIL=$((FAIL + 1))
  rm -f "$PWNED"
fi

echo "-----------------------------------------"
echo "test-adapter PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
