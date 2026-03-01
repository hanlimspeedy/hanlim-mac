#!/bin/bash
set -e

echo "==> 메뉴바에 볼륨 아이콘 항상 표시"

defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true
killall ControlCenter 2>/dev/null || true

echo ""
echo "완료: 메뉴바에 볼륨 아이콘 표시됨"
