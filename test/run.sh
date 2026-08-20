#!/usr/bin/env bash
# run.sh — design-bounce harness 마스터 테스트 러너
#
# CWD와 무관하게 자기 위치 기준으로 repo 루트를 찾아 아래 6개 섹션을 순서대로 실행한다:
#   1. JSON 유효성 (jq)      : config.schema.json + examples/petcycle.config.json 파싱
#   2. bash 문법 (bash -n)   : adapters/hooks/test 모든 .sh
#   3. 훅 유닛테스트          : test/test-hooks.sh
#   4. 어댑터 dry-run         : test/test-adapter.sh
#   5. 설치 유닛테스트        : test/test-install.sh
#   6. 내용 존재 (grep)       : knowledge/*.md + SKILL.md 필수 문자열
#
# 각 섹션 PASS/FAIL 출력. 하나라도 실패면 exit 1, 전부 통과면 "ALL PASS" + exit 0.
set -u

# CWD 독립: 스크립트 위치 기준으로 repo 루트로 이동
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

FAILED=0

section() { echo; echo "=== $1 ==="; }
report() {
  # $1 라벨  $2 성공여부(0/1)
  if [ "$2" -eq 0 ]; then
    echo "  PASS: $1"
  else
    echo "  FAIL: $1"
    FAILED=1
  fi
}

# ---------------------------------------------------------------------------
# 1. JSON 유효성
# ---------------------------------------------------------------------------
section "1. JSON 유효성 (jq)"
if ! command -v jq >/dev/null 2>&1; then
  echo "  FAIL: jq 미설치 (brew install jq)"
  FAILED=1
else
  for f in config.schema.json examples/petcycle.config.json; do
    if jq . "$REPO/$f" >/dev/null 2>&1; then
      report "jq . $f" 0
    else
      report "jq . $f" 1
    fi
  done
fi

# ---------------------------------------------------------------------------
# 2. bash 문법 (bash -n) — 모든 .sh
# ---------------------------------------------------------------------------
section "2. bash 문법 (bash -n)"
SH_FILES=$(find "$REPO/adapters" "$REPO/hooks" "$REPO/test" -name '*.sh' -type f | sort)
for sh in $SH_FILES; do
  rel="${sh#$REPO/}"
  if bash -n "$sh" 2>/dev/null; then
    report "bash -n $rel" 0
  else
    report "bash -n $rel" 1
  fi
done

# ---------------------------------------------------------------------------
# 3. 훅 유닛테스트
# ---------------------------------------------------------------------------
section "3. 훅 유닛테스트 (test-hooks.sh)"
if bash "$REPO/test/test-hooks.sh"; then
  report "test-hooks.sh" 0
else
  report "test-hooks.sh" 1
fi

# ---------------------------------------------------------------------------
# 4. 어댑터 dry-run
# ---------------------------------------------------------------------------
section "4. 어댑터 dry-run (test-adapter.sh)"
if bash "$REPO/test/test-adapter.sh"; then
  report "test-adapter.sh" 0
else
  report "test-adapter.sh" 1
fi

# ---------------------------------------------------------------------------
# 5. 설치 유닛테스트
# ---------------------------------------------------------------------------
section "5. 설치 유닛테스트 (test-install.sh)"
if bash "$REPO/test/test-install.sh"; then
  report "test-install.sh" 0
else
  report "test-install.sh" 1
fi

# ---------------------------------------------------------------------------
# 6. 내용 존재 (grep)
# ---------------------------------------------------------------------------
section "6. 내용 존재 (grep)"

grep_any() {
  # $1 라벨  $2 문자열  $3.. 파일들 — 하나라도 매치하면 PASS
  local label="$1" needle="$2"; shift 2
  if grep -qF -- "$needle" "$@" 2>/dev/null; then
    report "$label" 0
  else
    report "$label" 1
  fi
}

KN=("$REPO"/knowledge/*.md)
grep_any "knowledge: 4.5:1"   "4.5:1"   "${KN[@]}"
grep_any "knowledge: 8px"     "8px"     "${KN[@]}"
grep_any "knowledge: Blocker" "Blocker" "${KN[@]}"
grep_any "knowledge: 44pt"    "44pt"    "${KN[@]}"
grep_any "SKILL.md: Design Phase" "Design Phase" "$REPO/SKILL.md"
grep_any "SKILL.md: 정지조건"     "정지조건"     "$REPO/SKILL.md"

# ---------------------------------------------------------------------------
# 집계
# ---------------------------------------------------------------------------
echo
echo "========================================="
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PASS"
  exit 0
else
  echo "SOME TESTS FAILED"
  exit 1
fi
