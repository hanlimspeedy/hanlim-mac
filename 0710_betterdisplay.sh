#!/bin/bash
set -e

echo "==> BetterDisplay 설치 (외부 모니터 해상도/HiDPI 관리 도구)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask betterdisplay &>/dev/null; then
  echo "BetterDisplay 설치 중..."
  brew install --cask betterdisplay
else
  echo "BetterDisplay 이미 설치됨"
fi

open "/Applications/BetterDisplay.app"

echo ""
echo "완료: BetterDisplay 설치됨"
echo "  - TV로 인식되는 모니터에서도 해상도 자유 변경 가능"
echo "  - HiDPI(Retina) 스케일링 강제 적용 지원"
echo "  - 밝기, 볼륨 등 외부 모니터 DDC 제어"
echo ""
echo "※ 최초 실행 시 접근성 권한 허용 필요:"
echo "  시스템 설정 > 개인정보 보호 및 보안 > 접근성 > BetterDisplay ON"
echo ""
echo "※ https://github.com/waydabber/BetterDisplay"
