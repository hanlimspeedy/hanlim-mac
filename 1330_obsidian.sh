#!/bin/bash
set -e

echo "==> Obsidian 설치 (마크다운 기반 지식 관리 도구)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask obsidian &>/dev/null; then
  echo "Obsidian 설치 중..."
  brew install --cask obsidian
else
  echo "Obsidian 이미 설치됨"
fi

echo ""
echo "완료: Obsidian 설치됨"
echo "  - 로컬 마크다운 파일 기반 노트/지식 관리"
echo "  - Live Preview 모드에서 WYSIWYG 편집 지원"
echo "  - 양방향 링크, 그래프 뷰, 플러그인 생태계"
echo "  - 개인 사용 무료"
echo ""
echo "※ https://obsidian.md/"
