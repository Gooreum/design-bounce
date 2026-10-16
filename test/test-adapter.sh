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
check "navigate home → openurl booted deeplink" 'openurl booted petcycle://home'    navigate home
check "capture home → simctl io screenshot"    "simctl io booted screenshot"        capture home

# --- 명령 주입 / 경로 탐색 방지 (이슈 #4) ---
# 악성 config + 가짜 xcrun(PATH 앞에 둠)으로 실제 실행 경로를 검증한다.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/xcrun"
chmod +x "$TMP/bin/xcrun"
PWN="$TMP/pwned"
jq -n --arg p "$PWN" --arg dir "$TMP/shots" '{
  bundleId: ("x; touch " + $p),
  captureDir: ($dir + "/$(touch " + $p + ")"),
  screens: { evil: { deeplink: ("x\"; touch " + $p + "; \"") } }
}' > "$TMP/evil.json"

# assert: 악성 값이 명령으로 실행되지 않는다 (pwned 파일 미생성)
check_safe() {
  local label="$1"; shift
  rm -f "$PWN"
  DESIGN_BOUNCE_CONFIG="$TMP/evil.json" PATH="$TMP/bin:$PATH" \
    bash "$ADAPTER" "$@" >/dev/null 2>&1
  if [ ! -e "$PWN" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (주입된 명령이 실행됨)"
    FAIL=$((FAIL + 1))
  fi
}

check_safe "launch: bundleId 주입 차단"    launch
check_safe "navigate: deeplink 주입 차단"  navigate evil
check_safe "capture: captureDir 주입 차단" capture evil

# assert: 잘못된 screen_id 는 exit 2 로 거부
check_reject() {
  local label="$1"; shift
  local ec
  bash "$ADAPTER" "$@" --dry-run >/dev/null 2>&1; ec=$?
  if [ "$ec" -eq 2 ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (exit=$ec, 기대 2)"
    FAIL=$((FAIL + 1))
  fi
}

check_reject "capture: ../ screen_id 거부"   capture ../../etc/x
check_reject "navigate: \$() screen_id 거부" navigate 'home$(id)'

echo "-----------------------------------------"
echo "test-adapter PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
