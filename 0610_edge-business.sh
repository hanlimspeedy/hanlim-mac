#!/bin/bash
set -e

echo "==> Microsoft Edge for Business 설치 (Stable)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if [ -d "/Applications/Microsoft Edge.app" ]; then
  echo "Microsoft Edge 이미 설치됨"
  exit 0
fi

# Edge for Business (Stable) — 엔터프라이즈 안정 채널 pkg
# Microsoft 공식 다운로드: Apple Silicon (arm64) 전용
echo "Microsoft Edge for Business (Stable) 다운로드 중..."
TMPDIR=$(mktemp -d)
PKG_PATH="$TMPDIR/MicrosoftEdge.pkg"

curl -fSL -o "$PKG_PATH" \
  "https://go.microsoft.com/fwlink/?linkid=2093504"

echo "설치 중..."
sudo installer -pkg "$PKG_PATH" -target /
rm -rf "$TMPDIR"

echo ""
echo "완료: Microsoft Edge for Business 설치됨"
echo "  - 엔터프라이즈 안정 채널 (Stable)"
echo "  - 자동 업데이트: Microsoft AutoUpdate"
echo "※ 실행: open -a 'Microsoft Edge'"
