#!/usr/bin/env bash
# lib/verdict.sh — verdict.md 형식 파서 (screenshot-gate.sh / verdict-summary.sh 공용)
#
# 형식 계약은 knowledge/verdict-template.md 참고.
# 이 파일은 실행 스크립트가 아니라 `source` 되어 함수를 제공한다. jq 의존 없음.
#
# 노출 변수/함수:
#   DB_VERDICT_HEADER_RE     : 첫 줄 요약 헤더 정규식 (grep -E)
#   DB_VERDICT_SECTIONS      : 필수 섹션 이름 배열 (`## <이름>` 접두 일치)
#   db_verdict_parse F       : 헤더가 유효하면 "B H M N D"를 stdout 출력 후 return 0,
#                              파일 없음/빈 파일/헤더 오류면 return 1.
#   db_verdict_missing_sections F : 빠진 섹션 이름을 한 줄씩 출력. 모두 있으면 무출력.

DB_VERDICT_HEADER_RE='^blockers: [0-9]+, high: [0-9]+, medium: [0-9]+, nit: [0-9]+, deviations: [0-9]+$'
DB_VERDICT_SECTIONS=("잘된 점" "트랙 A" "트랙 B" "정지 판단")

# 첫 번째 비어 있지 않은 줄을 헤더로 파싱한다. (CRLF 방어로 \r 제거)
db_verdict_parse() {
  local file="$1" line
  [ -f "$file" ] || return 1
  line=$(grep -v '^[[:space:]]*$' "$file" | head -n 1 | tr -d '\r')
  printf '%s\n' "$line" | grep -Eq "$DB_VERDICT_HEADER_RE" || return 1
  printf '%s\n' "$line" | sed -E 's/^blockers: ([0-9]+), high: ([0-9]+), medium: ([0-9]+), nit: ([0-9]+), deviations: ([0-9]+)$/\1 \2 \3 \4 \5/'
}

# 필수 섹션 중 없는 것을 출력한다.
db_verdict_missing_sections() {
  local file="$1" s
  for s in "${DB_VERDICT_SECTIONS[@]}"; do
    grep -q "^## ${s}" "$file" 2>/dev/null || printf '%s\n' "$s"
  done
}
