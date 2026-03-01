#!/bin/bash
set -e

echo "==> Keka 설치 (압축 해제/생성 도구)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask keka &>/dev/null; then
  echo "Keka 설치 중..."
  brew install --cask keka
else
  echo "Keka 이미 설치됨"
fi

echo ""
echo "완료: Keka 설치됨"
echo "  - 압축 해제: RAR, 7z, TGZ, ZIP, TAR, ISO, BZ2, XZ 등"
echo "  - 압축 생성: 7z, ZIP, TAR, GZ, BZ2, XZ 등"
echo "  - 파일 드래그앤드롭으로 압축/해제 가능"
echo ""
echo "※ https://www.keka.io/"
