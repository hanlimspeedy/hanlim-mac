#!/bin/bash
set -e

echo "==> Homebrew 다중 사용자 공유 설정 (admin 그룹)"

# Homebrew 설치 확인
if [ ! -d /opt/homebrew ]; then
  echo "오류: /opt/homebrew 가 없습니다. 먼저 0300_homebrew.sh를 실행하세요."
  exit 1
fi

# 이미 설정되어 있으면 스킵
if [ -w /opt/homebrew/var/homebrew/locks ] 2>/dev/null; then
  echo "이미 설정됨: admin 그룹 쓰기 권한 확인됨"
  exit 0
fi

# admin 그룹 쓰기 권한 추가
echo "admin 그룹 쓰기 권한 설정 중..."
sudo chgrp -R admin /opt/homebrew
sudo chmod -R g+w /opt/homebrew

# 검증
if [ -w /opt/homebrew/var/homebrew/locks ]; then
  echo "완료: Homebrew 다중 사용자 공유 설정됨"
  echo "  - /opt/homebrew → admin 그룹 쓰기 허용"
  echo "  - admin 그룹에 속한 모든 사용자가 brew 사용 가능"
else
  echo "오류: 권한 설정 실패"
  exit 1
fi
