#!/bin/bash
set -e

echo "==> sudo 세션 활성화 (재부팅 후 매번 실행)"

# 0200_sudo-touchid.sh로 설정된 !tty_tickets + timestamp_timeout=-1 기반
# 이 스크립트를 실행하면 모든 터미널(Claude Code 포함)에서 sudo 사용 가능
sudo -v

# 검증: sudo가 실제로 동작하는지 확인
if sudo -n true 2>/dev/null; then
  echo "완료: sudo 세션 활성화됨 (로그아웃 전까지 유지)"
else
  echo "오류: sudo 세션 활성화 실패"
  echo "  1. /etc/sudoers.d/timeout 파일 확인: sudo cat /etc/sudoers.d/timeout"
  echo "  2. /etc/pam.d/sudo_local 파일 확인: cat /etc/pam.d/sudo_local"
  echo "  3. 문제 시 0200_sudo-touchid.sh를 다시 실행"
  exit 1
fi
