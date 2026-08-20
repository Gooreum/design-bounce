#!/usr/bin/env bash
set -euo pipefail
# design-bounce 설치: ~/.claude/skills/design-bounce 심링크 생성 + 의존성 체크 + 설치 검증
#
# 사용법:
#   ./install.sh            # 심링크 설치 (기본, git pull로 업데이트 반영됨)
#   ./install.sh --copy     # 심링크 대신 복사본 설치
#   ./install.sh --force    # 기존 링크/디렉토리 제거 후 재설치
#   ./install.sh --update   # git pull로 최신화 (심링크 설치용)
#   ./install.sh --version  # 현재 커밋 + origin 대비 뒤처짐 확인
#   ./install.sh --help     # 도움말
#
# 테스트 격리: CLAUDE_SKILLS_DIR 환경변수로 설치 위치를 override 할 수 있다.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"   # 테스트에서 override 가능
LINK="$SKILLS_DIR/design-bounce"
MODE="symlink"; FORCE=0; DO_UPDATE=0; DO_VERSION=0
GIT_TARGET="${DESIGN_BOUNCE_GIT_DIR:-$REPO_DIR}"   # 테스트 격리용 git 대상 override

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
    --update)      DO_UPDATE=1;;
    -v|--version)  DO_VERSION=1;;
    -h|--help)
      echo "usage: install.sh [--copy] [--force] [--update] [--version]"
      echo "  --copy    심링크 대신 복사본으로 설치"
      echo "  --force   기존 설치를 제거하고 재설치"
      echo "  --update  git pull로 최신화 (심링크 설치용)"
      echo "  --version 현재 커밋 + origin 대비 뒤처짐 확인"
      exit 0;;
    *) echo "unknown arg: $a" >&2; exit 2;;
  esac
done

# --- 의존성 체크 (경고만, 설치 자체는 진행) ---
command -v jq    >/dev/null || echo "⚠️  jq 없음 — 훅/어댑터 런타임에 필요: brew install jq"
command -v xcrun >/dev/null || echo "⚠️  Xcode CLI(xcrun) 없음 — rn-expo 어댑터에 필요(macOS)"
command -v node  >/dev/null || echo "⚠️  node 없음 — rn-expo build(expo)에 필요"

# --- 액션 분기 (--version / --update): 설치하지 않고 exit ---
db_is_git() { git -C "$GIT_TARGET" rev-parse --git-dir >/dev/null 2>&1; }
db_sha()    { git -C "$GIT_TARGET" rev-parse --short HEAD 2>/dev/null; }

if [ "$DO_VERSION" = 1 ]; then
  if db_is_git; then
    echo "design-bounce $(db_sha) ($(git -C "$GIT_TARGET" log -1 --format=%cd --date=short 2>/dev/null))"
    git -C "$GIT_TARGET" fetch --quiet 2>/dev/null || true
    behind=$(git -C "$GIT_TARGET" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    if [ "${behind:-0}" -gt 0 ]; then echo "⬆️  origin이 ${behind} 커밋 앞섬 — ./install.sh --update"; else echo "✅ 최신"; fi
  else
    echo "design-bounce (git 레포 아님 — 버전 확인 불가)"
  fi
  exit 0
fi

if [ "$DO_UPDATE" = 1 ]; then
  db_is_git || { echo "❌ ${GIT_TARGET} 는 git 레포가 아님 — 업데이트 불가" >&2; exit 1; }
  if ! git -C "$GIT_TARGET" symbolic-ref -q HEAD >/dev/null 2>&1; then
    echo "ℹ️  detached HEAD (submodule로 설치된 듯). 부모 레포에서:"
    echo "    git submodule update --remote <경로> && git add <경로> && git commit"
    exit 0
  fi
  if ! git -C "$GIT_TARGET" rev-parse -q --verify '@{u}' >/dev/null 2>&1; then
    echo "ℹ️  upstream 미설정 — 수동 git pull 필요"; exit 0
  fi
  before=$(db_sha); git -C "$GIT_TARGET" pull --ff-only; after=$(db_sha)
  if [ "$before" = "$after" ]; then echo "✅ 이미 최신 (${after})"; else echo "⬆️  업데이트: ${before} → ${after} (새 세션부터 반영)"; fi
  exit 0
fi

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
