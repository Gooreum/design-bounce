#!/usr/bin/env bash
# lib.sh — web-playwright 어댑터 공통 헬퍼 (source 전용)
#
# 명령은 config의 문자열 배열을 bash 배열로 읽어 "${ARR[@]}"로만 실행한다.
# eval / sh -c 를 쓰지 않으므로 인자 안의 `;`, `$()` 등은 셸에 해석되지 않는다.

CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"
STATE_DIR=".design-bounce"

die() {
  # $1 exit 코드  $2.. 메시지
  local code="$1"; shift
  echo "$*" >&2
  exit "$code"
}

[ -f "$CFG" ] || die 4 "config 없음: $CFG"

# read_cmd_array <필드> — config의 문자열 배열 필드를 전역 배열 CMD에 채운다.
# 필드가 없으면 CMD는 빈 배열. 배열이 아니거나 비문자열 원소가 있으면 exit 4.
# (macOS 기본 bash 3.2에는 mapfile이 없어 while read 루프를 쓴다)
read_cmd_array() {
  local field="$1" line
  CMD=()
  if ! jq -e --arg f "$field" \
      '.[$f] == null or (.[$f] | type == "array" and length > 0 and all(type == "string"))' \
      "$CFG" >/dev/null; then
    die 4 "config.$field 는 비어있지 않은 문자열 배열이어야 함: $CFG"
  fi
  while IFS= read -r line; do
    CMD+=("$line")
  done < <(jq -r --arg f "$field" '.[$f] // [] | .[]' "$CFG")
}

# print_cmd <args...> — dry-run용 셸 인용 문자열. 안전 문자만 있으면 그대로, 아니면 printf %q
print_cmd() {
  local out="" a
  for a in "$@"; do
    case "$a" in
      ''|*[!A-Za-z0-9_./:=,@%+-]*) out="$out$(printf '%q' "$a") " ;;
      *) out="$out$a " ;;
    esac
  done
  printf '%s' "${out% }"
}

# base_url — config.baseUrl (끝 / 제거). http(s)가 아니면 exit 4.
base_url() {
  local b
  b="$(jq -r '.baseUrl // empty' "$CFG")"
  [ -n "$b" ] || die 4 "config에 baseUrl 없음: $CFG"
  case "$b" in
    http://*|https://*) ;;
    *) die 4 "baseUrl은 http(s):// 로 시작해야 함: $b" ;;
  esac
  printf '%s' "${b%/}"
}

# check_screen_id <id> — 인자 누락 exit 2, 형식 위반 exit 2 (captureDir 밖 쓰기 차단)
check_screen_id() {
  local fn="$1" id="$2"
  [ -n "$id" ] || die 2 "$fn: screen_id 인자 필요"
  if ! printf '%s' "$id" | grep -Eq '^[A-Za-z0-9_-]+$'; then
    die 2 "$fn: screen_id는 [A-Za-z0-9_-]만 허용: $id"
  fi
}

# url_for <id> — baseUrl + screens[id].path. path 없음/상대경로면 exit 3.
url_for() {
  local id="$1" base p
  base="$(base_url)" || exit $?
  p="$(jq -r --arg id "$id" '.screens[$id].path // empty' "$CFG")"
  [ -n "$p" ] || die 3 "path 미정: config.screens.$id.path 필요"
  case "$p" in
    //*) die 3 "path는 /로 시작하는 상대 경로여야 함 (// 금지): $p" ;;
    /*) ;;
    *) die 3 "path는 /로 시작해야 함: $p" ;;
  esac
  printf '%s%s' "$base" "$p"
}

# health <url> — 2초 타임아웃 curl. 2xx/3xx면 0.
health() {
  curl -sf -o /dev/null --max-time 2 "$1"
}
