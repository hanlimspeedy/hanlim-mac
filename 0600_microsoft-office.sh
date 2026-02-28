#!/bin/bash
set -e

echo "==> Microsoft Office 설치 (Word, Excel, PowerPoint, Outlook, OneNote)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask microsoft-office &>/dev/null; then
  echo "Microsoft Office 설치 중... (약 2GB, 네트워크 상태에 따라 시간 소요)"
  # 대용량 파일이므로 다운로드 실패 시 최대 3회 재시도
  for i in 1 2 3; do
    if brew install --cask microsoft-office; then
      break
    fi
    echo "다운로드 실패, 재시도 ($i/3)..."
    [ "$i" -eq 3 ] && { echo "오류: 3회 시도 후에도 설치 실패. 네트워크 확인 후 다시 실행해주세요."; exit 1; }
  done
else
  echo "Microsoft Office 이미 설치됨"
fi

echo ""
echo "완료: Microsoft Office 설치됨"
echo "  - Word, Excel, PowerPoint, Outlook, OneNote"
echo "  - 앱 실행 후 회사 Microsoft 365 계정으로 로그인하여 라이선스 활성화"
