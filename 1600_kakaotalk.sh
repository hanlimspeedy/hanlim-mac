#!/bin/bash
set -e

echo "==> KakaoTalk 설치 (Mac App Store)"

# mas (Mac App Store CLI) 설치 확인
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! command -v mas &>/dev/null; then
  echo "mas 설치 중..."
  brew install mas
fi

# KakaoTalk 설치 (App Store ID: 869223134)
if mas list | grep -q 869223134; then
  echo "KakaoTalk 이미 설치됨"
else
  echo "KakaoTalk 설치 중..."
  mas install 869223134
fi

echo ""
echo "완료: KakaoTalk 설치됨"
echo "※ 실행: open -a KakaoTalk"
