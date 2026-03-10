#!/bin/bash
set -e

echo "==> Visual Studio Code 설치"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask visual-studio-code &>/dev/null; then
  echo "Visual Studio Code 설치 중..."
  brew install --cask visual-studio-code
else
  echo "Visual Studio Code 이미 설치됨"
fi

echo ""
echo "완료: Visual Studio Code 설치됨"
echo "  - 코드 편집기 (Microsoft)"
echo "  - 터미널에서 'code .' 명령으로 실행 가능"
