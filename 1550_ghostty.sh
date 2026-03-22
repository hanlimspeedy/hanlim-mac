#!/bin/bash
set -e

echo "==> Ghostty 터미널 설치 및 설정 (Claude Code + tmux 최적화)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# ───────────────────────────────────────────
# 1) Ghostty 설치
# ───────────────────────────────────────────
echo ""
echo "[1/2] Ghostty 설치..."

if ! brew list --cask ghostty &>/dev/null; then
  brew install --cask ghostty
else
  echo "  Ghostty 이미 설치됨"
fi

# ───────────────────────────────────────────
# 2) Ghostty 설정
#    - 굵은 모노스페이스 폰트 (Noto Sans Mono CJK KR)
#    - Claude Code + tmux에서 일렁임 없는 렌더링
# ───────────────────────────────────────────
echo ""
echo "[2/2] Ghostty 설정..."

mkdir -p ~/.config/ghostty

cat > ~/.config/ghostty/config << 'EOF'
# 폰트 설정 (굵은 모노스페이스, 눈 피로 감소)
font-family = "Noto Sans Mono CJK KR"
font-size = 16
font-style = Bold
font-style-bold = Bold

# 테마 (Catppuccin Mocha - 따뜻한 색감, 눈 피로 감소)
theme = Catppuccin Mocha

# 창 설정
window-padding-x = 8
window-padding-y = 8
window-save-state = always

# macOS 네이티브 탭/분할
macos-titlebar-style = tabs

# 클립보드
clipboard-read = allow
clipboard-write = allow

# 스크롤백 버퍼
scrollback-limit = 50000
EOF

echo "  설정 파일 생성: ~/.config/ghostty/config"

echo ""
echo "========================================="
echo "완료: Ghostty 터미널 설치 및 설정"
echo "========================================="
echo ""
echo "  - 폰트: Noto Sans Mono CJK KR Bold (16pt)"
echo "  - Claude Code + tmux에서 화면 일렁임 없음"
echo "  - DEC 2026 동기화 출력 네이티브 지원"
echo ""
echo "사용법:"
echo "  - Ghostty 실행 후 tmux → claude 실행"
echo "  - SSH는 기존대로 Termius 사용"
echo ""
echo "※ https://ghostty.org/"
