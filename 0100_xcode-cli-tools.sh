#!/bin/bash
set -e

echo "==> Xcode Command Line Tools 설치 중..."
if xcode-select -p &>/dev/null; then
  echo "이미 설치됨"
  exit 0
fi

xcode-select --install

echo ""
echo "설치 팝업이 떴습니다. 승인 후 설치 완료까지 기다려주세요."
echo "완료 후 다음 스크립트를 실행하세요."
