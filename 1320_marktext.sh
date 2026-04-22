#!/bin/bash
set -e

echo "==> MarkText 설치 (WYSIWYG 마크다운 에디터)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask mark-text &>/dev/null; then
  echo "MarkText 설치 중..."
  brew install --cask mark-text
else
  echo "MarkText 이미 설치됨"
fi

echo ""
echo "완료: MarkText 설치됨"
echo "  - WYSIWYG 실시간 마크다운 편집 (Typora 스타일)"
echo "  - 오픈소스 무료"
echo "  - GFM / 수식(KaTeX) / 다이어그램(Mermaid) 지원"
echo ""
echo "※ https://marktext.app/"
