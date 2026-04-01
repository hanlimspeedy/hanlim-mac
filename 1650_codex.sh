#!/bin/bash
set -e

echo "==> Codex 설치 (OpenAI 터미널 코딩 에이전트)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask codex &>/dev/null; then
  echo "Codex 설치 중..."
  brew install --cask codex
else
  echo "Codex 이미 설치됨"
fi

echo ""
echo "완료: Codex 설치됨"
echo "  - OpenAI의 터미널 기반 코딩 에이전트"
echo "  - 터미널에서 자연어로 코드 작성/수정/실행"
echo "  - 의존성: ripgrep"
echo ""
echo "※ https://github.com/openai/codex"
