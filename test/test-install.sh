#!/usr/bin/env bash
set -euo pipefail
# test-install.sh — install.sh 유닛테스트
#
# CLAUDE_SKILLS_DIR를 임시 디렉토리로 override 하여 실제 ~/.claude/skills를
# 건드리지 않고 설치 동작을 검증한다. 5개 케이스:
#   1) 신규 설치 → 심링크 생성
#   2) SKILL.md 해석 (심링크 통해 파일 접근)
#   3) idempotent 재설치 → exit 0
#   4) --help → exit 0
#   5) 알 수 없는 인자 → exit≠0

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() {
  # $1 라벨  $2 평가할 표현식(문자열)
  if eval "$2"; then
    echo "  PASS: $1"; pass=$((pass+1))
  else
    echo "  FAIL: $1"; fail=$((fail+1))
  fi
}

# 1) 신규 설치 → 심링크 생성 + SKILL.md 해석 + exit 0
CLAUDE_SKILLS_DIR="$TMP/skills" bash "$REPO/install.sh" >/dev/null
check "심링크 생성"     "[ -L '$TMP/skills/design-bounce' ]"
check "SKILL.md 해석"   "[ -f '$TMP/skills/design-bounce/SKILL.md' ]"

# 2) 재실행 idempotent → exit 0
check "idempotent 재설치" "CLAUDE_SKILLS_DIR='$TMP/skills' bash '$REPO/install.sh' >/dev/null 2>&1"

# 3) --help → exit 0
check "--help exit 0" "bash '$REPO/install.sh' --help >/dev/null 2>&1"

# 4) 알 수 없는 인자 → exit≠0
check "unknown arg 거부" "! bash '$REPO/install.sh' --bogus >/dev/null 2>&1"

echo "test-install PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
