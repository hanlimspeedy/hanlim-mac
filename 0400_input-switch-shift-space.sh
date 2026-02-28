#!/bin/bash
set -e

echo "==> Karabiner-Elements 설치 + Shift+Space 한영전환 + Ctrl↔Cmd 스왑"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# Karabiner-Elements 설치
if ! brew list --cask karabiner-elements &>/dev/null; then
  brew install --cask karabiner-elements
fi

# Karabiner 설정 복사
mkdir -p ~/.config/karabiner
cp "$(dirname "$0")/config/karabiner.json" ~/.config/karabiner/karabiner.json

echo ""
echo "완료: Karabiner-Elements 설정 적용"
echo "  - Ctrl ↔ Cmd 스왑 (윈도우 스타일)"
echo "  - Shift+Space 한영전환 (두벌식 ↔ ABC)"
echo ""
echo "※ 최초 설치 시 Karabiner-Elements 실행 후 아래 권한 허용 필요:"
echo "  1. 입력 모니터링: Karabiner-Core-Service"
echo "  2. 로그인 항목: Karabiner 백그라운드 항목 ON"
echo "  3. 드라이버 확장 프로그램: Karabiner-VirtualHIDDevice-Manager ON"
echo "  ※ 권한 설정 후 재부팅 필요"
