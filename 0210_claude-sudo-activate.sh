#!/bin/bash
# 재부팅 후 Claude Code에서 sudo 사용 가능하도록 인증 활성화
# 사전조건: 0200_sudo-touchid.sh 가 한 번 실행되어 있어야 함
# !tty_tickets 설정으로 모든 터미널에서 sudo 공유됨

echo "==> 재부팅 후 sudo 활성화 (Claude Code용)"
sudo -v && echo "완료: 모든 터미널에서 sudo 사용 가능" || echo "실패"
