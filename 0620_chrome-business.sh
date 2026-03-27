#!/bin/bash
set -e

echo "==> Google Chrome for Business 설치 (Stable)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if [ -d "/Applications/Google Chrome.app" ]; then
  echo "Google Chrome 이미 설치됨"
  exit 0
fi

# Chrome for Business (Stable) — 엔터프라이즈 안정 채널 pkg
# Google 공식 Enterprise Bundle (Apple Silicon universal)
echo "Google Chrome for Business (Stable) 다운로드 중..."
TMPDIR=$(mktemp -d)
PKG_PATH="$TMPDIR/GoogleChrome.pkg"

curl -fSL -o "$PKG_PATH" \
  "https://dl.google.com/dl/chrome/mac/universal/stable/gcem/GoogleChrome.pkg"

echo "설치 중..."
sudo installer -pkg "$PKG_PATH" -target /
rm -rf "$TMPDIR"

echo ""
echo "완료: Google Chrome for Business 설치됨"
echo "  - 엔터프라이즈 안정 채널 (Stable)"
echo "  - 사용자 프로필 없이 설치됨 (관리자 배포 방식)"
echo "※ 실행: open -a 'Google Chrome'"
