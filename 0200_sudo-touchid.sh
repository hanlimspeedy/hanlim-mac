#!/bin/bash
set -e

echo "==> Touch ID sudo + 공유 세션 + 타임아웃 없음"

# 설정 파일 생성 (이미 있으면 덮어씀, 재부팅 후에도 유지됨)
sudo sh -c '
echo "auth       sufficient     pam_tid.so" > /etc/pam.d/sudo_local
printf "Defaults timestamp_timeout=-1\nDefaults !tty_tickets\n" > /etc/sudoers.d/timeout
chmod 440 /etc/sudoers.d/timeout
'

# sudo 세션 활성화
sudo -v

# 검증: sudo가 실제로 동작하는지 확인
if sudo -n true 2>/dev/null; then
  echo "완료: Touch ID sudo, 모든 터미널 공유, 로그아웃 전까지 유지"
else
  echo "오류: sudo 세션 활성화 실패"
  echo "  1. /etc/sudoers.d/timeout 확인: sudo cat /etc/sudoers.d/timeout"
  echo "  2. /etc/pam.d/sudo_local 확인: cat /etc/pam.d/sudo_local"
  exit 1
fi
