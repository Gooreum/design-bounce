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
#   db_tool_file_path    : stdin의 훅 입력 JSON에서 .tool_input.file_path를 출력.
#                          stdin이 없거나(터미널) 파싱 실패/필드 없음이면 빈 문자열.
#   db_path_in_state_dir P : 경로 P가 $DB_STATE_DIR 아래면 exit 0, 아니면(판별 불가 포함) 1.
#
# state.json phase 허용값: design | loop | review | done
#   design=명세 단계, loop=스크린샷 루프, review=사람 최종 승인 대기, done=사람 승인 완료.
#   값 검증은 하지 않는다 — 미지의 값은 각 훅에서 통과(fail-open).

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

# 훅 입력 JSON(stdin)에서 대상 파일 경로를 읽는다.
db_tool_file_path() {
  # stdin이 터미널이면 훅 입력이 없는 것 → 빈 문자열
  [ -t 0 ] && return 0
  jq -r '.tool_input.file_path // empty' 2>/dev/null || true
}

# 경로가 state 디렉토리 아래인지 판별한다.
#   $1: 대상 파일 경로 (절대 또는 CWD 기준 상대)
#   상위 이동(..)이 섞인 경로는 판별 불가로 보고 1을 돌려준다.
db_path_in_state_dir() {
  local p="$1" sd
  [ -n "$p" ] || return 1
  case "/$p/" in */../*) return 1 ;; esac
  sd=$(cd "$DB_STATE_DIR" 2>/dev/null && pwd) || return 1
  case "$p" in /*) ;; *) p="$PWD/${p#./}" ;; esac
  case "$p" in "$sd"/*) return 0 ;; esac
  return 1
}
