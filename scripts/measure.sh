#!/usr/bin/env bash
# measure.sh — 디자인 토큰 결정론적 측정 (WCAG 대비 + 간격 그리드)
#
# 판정자(Vision)의 눈대중 대신, 같은 입력이면 항상 같은 결과를 내는 수치 측정을
# `.design-bounce/steps/step-N/measure.json`에 남긴다. 판정자는 이 파일을 스크린샷보다
# 먼저 읽고 violations[]를 수치와 함께 [Blocker]로 인용한다 (SKILL.md 트랙 B).
#
# 사용법:
#   scripts/measure.sh --step N [--config <path>]
#
# 입력:
#   config : --config 또는 ${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}
#            의 `measure` 블록 (config.schema.json 참조)
#   tokens : measure.tokensJson, 없으면 `tokens`가 .json일 때 그것. (JSON 토큰만 지원)
# 출력:
#   ${DESIGN_BOUNCE_DIR:-.design-bounce}/steps/step-N/measure.json
#
# exit code: 0 = pass/skipped, 1 = 위반 있음, 2 = 입력 오류(infra-fail)

set -u

usage() {
  echo "usage: measure.sh --step N [--config <path>]" >&2
  exit 2
}

STEP=""
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"
while [ $# -gt 0 ]; do
  case "$1" in
    --step)   [ $# -ge 2 ] || usage; STEP="$2"; shift 2 ;;
    --config) [ $# -ge 2 ] || usage; CFG="$2"; shift 2 ;;
    *) usage ;;
  esac
done

case "$STEP" in
  ''|*[!0-9]*) echo "measure.sh: --step 은 양의 정수여야 한다" >&2; usage ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "measure.sh: jq 미설치 (brew install jq)" >&2
  exit 2
fi
# pow 는 jq 1.6+ 내장 — 대비 계산에 필수
if ! jq -n 'pow(2;2)' >/dev/null 2>&1; then
  echo "measure.sh: jq 1.6 이상 필요 (pow 미지원)" >&2
  exit 2
fi

OUT_DIR="${DESIGN_BOUNCE_DIR:-.design-bounce}/steps/step-$STEP"
OUT="$OUT_DIR/measure.json"
mkdir -p "$OUT_DIR" || exit 2
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# status=skipped|error 결과 기록
#   $1 status  $2 reason  $3 tokensFile(없으면 "")
write_simple() {
  jq -n --argjson step "$STEP" --arg now "$NOW" --arg status "$1" \
        --arg reason "$2" --arg tf "$3" '
    {version: 1, step: $step, generatedAt: $now,
     tokensFile: (if $tf == "" then null else $tf end),
     status: $status, reason: $reason,
     violations: [], skipped: []}' > "$OUT"
}

if [ ! -f "$CFG" ]; then
  write_simple error "config 없음: $CFG" ""
  echo "measure.sh: config 없음: $CFG" >&2
  exit 2
fi
if ! MEASURE=$(jq -c '.measure // null' "$CFG" 2>/dev/null); then
  write_simple error "config JSON 파싱 실패: $CFG" ""
  echo "measure.sh: config JSON 파싱 실패: $CFG" >&2
  exit 2
fi

if [ "$MEASURE" = "null" ]; then
  write_simple skipped "measure 미설정" ""
  echo "measure: skipped (measure 미설정) → $OUT"
  exit 0
fi

TOKENS=$(jq -r '
  if (.measure.tokensJson // "") != "" then .measure.tokensJson
  elif ((.tokens // "") | endswith(".json")) then .tokens
  else "" end' "$CFG")

if [ -z "$TOKENS" ]; then
  write_simple skipped "JSON 토큰 파일 미지정 (measure.tokensJson 필요)" ""
  echo "measure: skipped (JSON 토큰 파일 미지정) → $OUT"
  exit 0
fi
if [ ! -f "$TOKENS" ]; then
  write_simple error "토큰 파일 없음: $TOKENS" "$TOKENS"
  echo "measure.sh: 토큰 파일 없음: $TOKENS" >&2
  exit 2
fi
if ! jq empty "$TOKENS" >/dev/null 2>&1; then
  write_simple error "토큰 JSON 파싱 실패: $TOKENS" "$TOKENS"
  echo "measure.sh: 토큰 JSON 파싱 실패: $TOKENS" >&2
  exit 2
fi

# 대비·그리드·radius 판정을 하나의 jq 프로그램에서 수행한다.
jq --argjson m "$MEASURE" --argjson step "$STEP" --arg now "$NOW" \
   --arg tf "$TOKENS" '
  . as $tok
  | def tpath: split(".");
    def hexval: explode | map(if . >= 97 then . - 87 elif . >= 65 then . - 55 else . - 48 end)
                | .[0] * 16 + .[1];
    # "#RGB" | "#RRGGBB" → [r,g,b] (0~255). 그 외 형식은 null.
    def rgb:
      if type != "string" then null
      elif test("^#[0-9A-Fa-f]{6}$") then [.[1:3], .[3:5], .[5:7]] | map(hexval)
      elif test("^#[0-9A-Fa-f]{3}$") then [.[1:2], .[2:3], .[3:4]] | map(. + . | hexval)
      else null end;
    # WCAG 2.x 상대휘도
    def lum: map(. / 255 | if . <= 0.03928 then . / 12.92 else pow((. + 0.055) / 1.055; 2.4) end)
             | 0.2126 * .[0] + 0.7152 * .[1] + 0.0722 * .[2];
    # 숫자 또는 "16px" 문자열 → 숫자. 그 외(rem, % 등)는 null.
    def pxnum:
      if type == "number" then .
      elif type == "string" and test("^-?[0-9]+(\\.[0-9]+)?(px)?$") then rtrimstr("px") | tonumber
      else null end;
    # 토큰 서브트리의 잎 노드 [{path, value}]
    def leaves($roots):
      [ $roots[] as $r
        | ($r | tpath) as $p
        | ($tok | getpath($p)) as $sub
        | select($sub != null)
        | if ($sub | type) == "object" or ($sub | type) == "array"
          then $sub | paths(scalars) as $lp
               | {path: ($p + ($lp | map(tostring)) | join(".")), value: ($sub | getpath($lp))}
          else {path: $r, value: $sub} end ];

    ($m.gridBase // 8) as $base
  | ($m.gridAllow // [4, 12]) as $allow
  | ($m.gridPaths // ["spacing", "space"]) as $gridPaths
  | ($m.radiusPaths // ["radius", "radii"]) as $radiusPaths

  # --- 대비 ---
  | [ ($m.colorPairs // [])[]
      | . as $pair
      | ("\(.fg) on \(.bg)") as $target
      | ($tok | getpath($pair.fg | tpath)) as $fgv
      | ($tok | getpath($pair.bg | tpath)) as $bgv
      | if $fgv == null then {skip: {target: $target, reason: "토큰 경로 없음: \($pair.fg)"}}
        elif $bgv == null then {skip: {target: $target, reason: "토큰 경로 없음: \($pair.bg)"}}
        elif ($fgv | rgb) == null then {skip: {target: $target, reason: "지원하지 않는 색 형식: \($fgv)"}}
        elif ($bgv | rgb) == null then {skip: {target: $target, reason: "지원하지 않는 색 형식: \($bgv)"}}
        else
          ([($fgv | rgb | lum), ($bgv | rgb | lum)] | sort) as [$lo, $hi]
          | (($hi + 0.05) / ($lo + 0.05)) as $ratio
          | (if ($pair.large // false) then 3.0 else 4.5 end) as $req
          | {checked: true,
             violation: (if $ratio < $req then
               {rule: "wcag-contrast", severity: "Blocker", target: $target,
                measured: (($ratio * 100 | floor) / 100), required: $req,
                detail: {fg: $fgv, bg: $bgv, large: ($pair.large // false)}}
             else null end)}
        end ] as $contrast

  # --- 간격 그리드 ---
  | [ leaves($gridPaths)[]
      | (.value | pxnum) as $n
      | if $n == null then {skip: {target: .path, reason: "지원하지 않는 간격 형식: \(.value)"}}
        else
          ($n | fabs) as $a
          | {checked: true,
             violation: (if ($a == ($a | floor) and ($a % $base) == 0) or ($allow | index([$a])) != null
               then null
               else {rule: "spacing-grid", severity: "Blocker", target: .path,
                     measured: $n, required: "\($base)의 배수 또는 \($allow | tojson)"} end)}
        end ] as $grid

  # --- radius (정보만) ---
  | [ leaves($radiusPaths)[] | .value | pxnum | select(. != null) ] | unique as $radii

  | ([$contrast[], $grid[]] | map(.violation | select(. != null))) as $violations
  | {version: 1, step: $step, generatedAt: $now, tokensFile: $tf,
     status: (if ($violations | length) > 0 then "fail" else "pass" end),
     summary: {
       contrast: {checked: ([$contrast[] | select(.checked)] | length),
                  violations: ([$contrast[] | .violation | select(. != null)] | length)},
       grid: {checked: ([$grid[] | select(.checked)] | length),
              violations: ([$grid[] | .violation | select(. != null)] | length)}},
     violations: $violations,
     skipped: [$contrast[], $grid[] | .skip | select(. != null)],
     info: {radiusDistinct: $radii}}
' "$TOKENS" > "$OUT.tmp" || {
  rm -f "$OUT.tmp"
  write_simple error "측정 실패 (measure 설정 확인)" "$TOKENS"
  echo "measure.sh: 측정 실패 (measure 설정 확인)" >&2
  exit 2
}
mv "$OUT.tmp" "$OUT"

STATUS=$(jq -r '.status' "$OUT")
NV=$(jq '.violations | length' "$OUT")
echo "measure: $STATUS (violations=$NV) → $OUT"
[ "$STATUS" = "fail" ] && exit 1
exit 0
