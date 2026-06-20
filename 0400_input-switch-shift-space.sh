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

# macOS 입력 소스 전환 단축키 활성화: Ctrl+Option+Space
# Karabiner는 Shift+Space를 이 단축키로 변환한다.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>65535</integer><integer>0</integer></array></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>786432</integer></array></dict></dict>"
defaults write com.apple.HIToolbox AppleGlobalTextInputProperties -dict TextInputGlobalPropertyPerContextInput -bool false
killall cfprefsd 2>/dev/null || true
killall TextInputMenuAgent 2>/dev/null || true
killall keyboardservicesd 2>/dev/null || true

echo ""
echo "완료: Karabiner-Elements 설정 적용"
echo "  - Ctrl ↔ Cmd 스왑 (윈도우 스타일)"
echo "  - Shift+Space → Ctrl+Option+Space → 한영전환 (두벌식 ↔ ABC)"
echo ""
echo "※ 최초 설치 시 Karabiner-Elements 실행 후 아래 권한 허용 필요:"
echo "  1. 입력 모니터링: Karabiner-Core-Service"
echo "  2. 로그인 항목: Karabiner 백그라운드 항목 ON"
echo "  3. 드라이버 확장 프로그램: Karabiner-VirtualHIDDevice-Manager ON"
echo "  ※ 권한 설정 후 재부팅 필요"
