#!/bin/bash
set -e

echo "==> sudo 세션 활성화 (재부팅 후 매번 실행)"

# 0200_sudo-touchid.sh로 설정된 !tty_tickets + timestamp_timeout=-1 기반
# 이 스크립트를 실행하면 모든 터미널(Claude Code 포함)에서 sudo 사용 가능
sudo -v

echo "완료: sudo 세션 활성화됨 (로그아웃 전까지 유지)"
