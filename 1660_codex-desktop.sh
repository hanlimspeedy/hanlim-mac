#!/bin/bash
set -e

echo "==> Codex Desktop 재설치 (OpenAI 코딩 에이전트 데스크탑 앱)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# 잔여 파일을 sudo로 직접 제거 (코드 서명된 앱은 chown 불가하므로 통째로 삭제)
if [ -e "/Applications/Codex.app" ]; then
  echo "/Applications/Codex.app 제거 중 (sudo)..."
  sudo rm -rf "/Applications/Codex.app"
fi
if [ -d "/opt/homebrew/Caskroom/codex-app" ]; then
  echo "Caskroom 디렉터리 제거 중 (sudo)..."
  sudo rm -rf "/opt/homebrew/Caskroom/codex-app"
fi

# brew 메타데이터 정리 (--zap 으로 모든 흔적 제거 시도, 실패 무시)
brew uninstall --cask --force --zap codex-app 2>/dev/null || true

# 재설치
echo "Codex Desktop 설치 중..."
brew install --cask codex-app

echo ""
echo "완료: Codex Desktop 재설치됨"
echo "  - OpenAI의 코딩 에이전트 데스크탑 앱 (GUI)"
echo "  - 여러 코딩 에이전트 작업 관리"
echo "  - 터미널 CLI 버전은 1650_codex.sh 참고"
echo ""
echo "※ https://openai.com/codex"
