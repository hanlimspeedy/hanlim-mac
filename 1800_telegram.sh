#!/bin/bash
set -e

echo "==> Telegram 설치"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask telegram &>/dev/null; then
  echo "Telegram 설치 중..."
  brew install --cask telegram
else
  echo "Telegram 이미 설치됨"
fi

echo ""
echo "완료: Telegram 설치됨"
echo "※ 실행: open -a Telegram"
