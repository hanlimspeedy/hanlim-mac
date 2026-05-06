#!/bin/bash
set -e

echo "==> Codex Desktop 설치 (OpenAI 코딩 에이전트 데스크톱 앱)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask codex-app &>/dev/null; then
  echo "Codex Desktop 설치 중..."
  brew install --cask codex-app
else
  echo "Codex Desktop 이미 설치됨"
fi

echo ""
echo "완료: Codex Desktop 설치됨"
echo "  - OpenAI의 코딩 에이전트 관리용 데스크톱 앱"
echo "  - 여러 코딩 에이전트를 GUI로 실행/관리"
echo "  - 자동 업데이트 지원 (auto_updates)"
echo "  - 요구사항: macOS 12 이상"
echo ""
echo "※ https://openai.com/codex"
