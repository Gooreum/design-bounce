#!/usr/bin/env bash
# lib/state.sh — design-bounce 게이트 훅 공용 헬퍼
#
# 채택 프로젝트 루트의 `.design-bounce/state.json`을 읽는다.
# 이 파일은 실행 스크립트가 아니라 `source` 되어 함수를 제공한다.
#
# 노출 변수/함수:
#   DB_STATE_DIR   : state 디렉토리 경로. env DESIGN_BOUNCE_DIR로 override(기본 .design-bounce).
#   DB_STATE_FILE  : state.json 전체 경로 ($DB_STATE_DIR/state.json).
#   db_state_exists      : state.json이 존재하면 exit 0, 아니면 1.
#   db_state_field K D   : state.json의 최상위 필드 K를 jq로 읽어 stdout 출력.
#                          없거나 null이면 기본값 D. state 파일 자체가 없어도 D.

# state 디렉토리/파일 경로 결정 (env override 지원)
DB_STATE_DIR="${DESIGN_BOUNCE_DIR:-.design-bounce}"
DB_STATE_FILE="$DB_STATE_DIR/state.json"

# state.json 존재 여부
db_state_exists() {
  [ -f "$DB_STATE_FILE" ]
}

# 최상위 필드 하나를 안전하게 읽는다.
#   $1: 키 (예: phase, current_step, spec_approved)
#   $2: 기본값 (필드 없음/null/파일 없음 시)
db_state_field() {
  local key="$1" default="$2" val
  if [ ! -f "$DB_STATE_FILE" ]; then
    printf '%s' "$default"
    return 0
  fi
  # jq 파싱 실패(깨진 JSON)해도 기본값으로 폴백
  val=$(jq -r --arg d "$default" ".${key} // \$d" "$DB_STATE_FILE" 2>/dev/null) || val="$default"
  # jq가 리터럴 null을 문자열로 뱉는 극단 케이스 방어
  [ "$val" = "null" ] && val="$default"
  printf '%s' "$val"
}
