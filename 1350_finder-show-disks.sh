#!/bin/bash
set -e

echo "==> Finder 데스크톱/사이드바에 모든 디스크 표시"

# HDD/외장/이동식/마운트 서버 모두 데스크톱과 사이드바에 표시
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true

# Finder 재시작 (defaults 변경 적용)
killall Finder 2>/dev/null || true

echo ""
echo "완료: HDD/외장/이동식/마운트 서버 모두 표시"
