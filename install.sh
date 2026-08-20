#!/usr/bin/env bash
set -euo pipefail
# design-bounce 설치: ~/.claude/skills/design-bounce 심링크 생성 + 의존성 체크 + 설치 검증
#
# 사용법:
#   ./install.sh            # 심링크 설치 (기본, git pull로 업데이트 반영됨)
#   ./install.sh --copy     # 심링크 대신 복사본 설치
#   ./install.sh --force    # 기존 링크/디렉토리 제거 후 재설치
#   ./install.sh --help     # 도움말
#
# 테스트 격리: CLAUDE_SKILLS_DIR 환경변수로 설치 위치를 override 할 수 있다.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"   # 테스트에서 override 가능
LINK="$SKILLS_DIR/design-bounce"
MODE="symlink"; FORCE=0

# --- 실제 설치 동작 (파싱 전에 함수로 정의) ---
install_link() {
  if [ "$MODE" = "copy" ]; then
    cp -R "$REPO_DIR" "$LINK"
    echo "✅ 복사 설치: $LINK (원본: $REPO_DIR)"
  else
    ln -s "$REPO_DIR" "$LINK"
    echo "✅ 심링크 설치: $LINK -> $REPO_DIR"
  fi
}

# --- 인자 파싱 ---
for a in "$@"; do
  case "$a" in
    --copy)  MODE="copy";;
    --force) FORCE=1;;
    -h|--help)
      echo "usage: install.sh [--copy] [--force]"
      echo "  --copy   심링크 대신 복사본으로 설치"
      echo "  --force  기존 설치를 제거하고 재설치"
      exit 0;;
    *) echo "unknown arg: $a" >&2; exit 2;;
  esac
done

# --- 의존성 체크 (경고만, 설치 자체는 진행) ---
command -v jq    >/dev/null || echo "⚠️  jq 없음 — 훅/어댑터 런타임에 필요: brew install jq"
command -v xcrun >/dev/null || echo "⚠️  Xcode CLI(xcrun) 없음 — rn-expo 어댑터에 필요(macOS)"
command -v node  >/dev/null || echo "⚠️  node 없음 — rn-expo build(expo)에 필요"

# --- 설치 ---
mkdir -p "$SKILLS_DIR"
if [ -e "$LINK" ] || [ -L "$LINK" ]; then
  # 이미 우리 레포를 가리키는 심링크면 idempotent 성공
  if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$REPO_DIR" ]; then
    echo "✅ 이미 설치됨: $LINK -> $REPO_DIR"
  elif [ "$FORCE" = 1 ]; then
    rm -rf "$LINK"
    install_link
  else
    echo "❌ 이미 존재: $LINK (덮어쓰려면 --force)" >&2
    exit 1
  fi
else
  install_link
fi

# --- 검증 ---
[ -f "$LINK/SKILL.md" ] || { echo "❌ 검증 실패: SKILL.md 미발견" >&2; exit 1; }
echo "✅ 설치 완료. 새 세션에서 /design-bounce 사용 가능."
echo "   프로젝트 훅 강제: hooks/install.md 참고"
