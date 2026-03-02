#!/bin/bash
set -e

echo "==> Better Shot 설치 (스크린샷 캡처 + 즉시 편집 도구)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask bettershot &>/dev/null; then
  echo "Better Shot 설치 중..."
  brew install --cask bettershot
else
  echo "Better Shot 이미 설치됨"
fi

open -a bettershot

echo ""
echo "완료: Better Shot 설치됨"
echo "  - 캡처 후 화살표, 텍스트, 도형, 번호, OCR 등 즉시 편집 가능"
echo "  - 무료, 오픈소스 (BSD-3-Clause)"
echo "  - Apple Silicon 네이티브"
echo ""
echo "※ 최초 실행 시 화면 녹화 권한 허용 필요:"
echo "  시스템 설정 > 개인정보 보호 및 보안 > 화면 녹화 > bettershot ON"
echo ""
echo "※ https://github.com/KartikLabhshetwar/better-shot"
