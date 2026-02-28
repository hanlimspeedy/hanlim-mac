#!/bin/bash
set -e

echo "==> 배터리 충전 80% 제한 설정"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# battery cask 설치 (actuallymentor/battery)
if ! brew list --cask battery &>/dev/null; then
  echo "battery 설치 중..."
  brew install --cask battery
else
  echo "battery 이미 설치됨"
fi

# battery CLI 존재 확인
if [ ! -f /usr/local/bin/battery ]; then
  echo "오류: battery CLI가 설치되지 않았습니다."
  echo "battery.app을 한 번 실행한 후 다시 시도해주세요."
  exit 1
fi

# 80% 충전 제한 설정
echo "80% 충전 제한 설정 중..."
battery maintain 80

echo ""
echo "완료: 배터리 충전 80% 제한 설정됨"
echo "  - 80% 이상 충전 차단, 이하로 내려가면 자동 충전"
echo "  - 재부팅 후에도 유지됨"
echo ""
echo "유용한 명령어:"
echo "  battery status        # 현재 배터리 상태 확인"
echo "  battery maintain stop # 충전 제한 해제"
echo ""
echo "※ GitHub: https://github.com/actuallymentor/battery"
