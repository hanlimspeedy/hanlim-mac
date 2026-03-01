#!/bin/bash
set -e

echo "==> IINA 설치 (macOS 네이티브 동영상 플레이어)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask iina &>/dev/null; then
  echo "IINA 설치 중..."
  brew install --cask iina
else
  echo "IINA 이미 설치됨"
fi

echo ""
echo "완료: IINA 설치됨"
echo "  - macOS 네이티브 동영상 플레이어 (Swift, 오픈소스)"
echo "  - 대부분의 동영상 포맷 지원"
echo "  - 다크모드, 트랙패드 제스처, PIP 지원"
echo ""
echo "※ https://iina.io/"
