#!/bin/bash
set -e

echo "==> Google Drive 설치"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if [ -d "/Applications/Google Drive.app" ]; then
  echo "Google Drive 이미 설치됨"
  exit 0
fi

echo "Google Drive 설치 중 (brew cask)..."
brew install --cask google-drive

echo ""
echo "완료: Google Drive 설치됨"
echo "※ 실행: open -a 'Google Drive'"
