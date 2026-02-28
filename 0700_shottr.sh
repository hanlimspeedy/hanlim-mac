#!/bin/bash
set -e

echo "==> Shottr 설치 (스크린샷 캡처 + 즉시 편집 도구)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask shottr &>/dev/null; then
  echo "Shottr 설치 중..."
  brew install --cask shottr
else
  echo "Shottr 이미 설치됨"
fi

open -a Shottr

echo ""
echo "완료: Shottr 설치됨"
echo "  - 캡처 후 화살표, 텍스트, 블러, 도형, OCR 등 즉시 편집 가능"
echo "  - 메뉴바 아이콘에서 단축키 설정 가능"
echo ""
echo "※ 최초 실행 시 화면 녹화 권한 허용 필요:"
echo "  시스템 설정 > 개인정보 보호 및 보안 > 화면 녹화 > Shottr ON"
echo ""
echo "※ https://shottr.cc/"
