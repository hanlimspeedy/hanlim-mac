#!/bin/bash
set -e

echo "==> 메뉴바에 볼륨 아이콘 항상 표시"

# 제어 센터 설정: 사운드 메뉴바 표시
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Sound" -bool true

echo ""
echo "완료: 메뉴바에 볼륨 아이콘 표시 설정됨"
echo "※ 로그아웃 후 재로그인하면 적용됩니다."
echo ""
echo "만약 적용되지 않으면 아래 명령으로 수동 설정:"
echo "  open 'x-apple.systempreferences:com.apple.ControlCenter-Settings.extension'"
echo "  → 사운드 항목에서 '메뉴 막대에 항상 표시' 선택"
