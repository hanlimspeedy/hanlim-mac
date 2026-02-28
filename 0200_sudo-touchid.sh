#!/bin/bash
set -e

echo "==> Touch ID sudo + 공유 세션 + 타임아웃 없음"

# 최초 실행 시 설정 파일 생성 (이미 있으면 덮어씀)
sudo sh -c '
echo "auth       sufficient     pam_tid.so" > /etc/pam.d/sudo_local
printf "Defaults timestamp_timeout=-1\nDefaults !tty_tickets\n" > /etc/sudoers.d/timeout
chmod 440 /etc/sudoers.d/timeout
'

# sudo 인증 활성화 (재부팅 후에도 이 스크립트만 실행하면 됨)
sudo -v

echo "완료: Touch ID sudo, 모든 터미널 공유, 로그아웃 전까지 유지"
