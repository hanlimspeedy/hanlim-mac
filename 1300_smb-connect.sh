#!/bin/bash
set -e

echo "==> Windows SMB 공유 폴더 연결"

# 환경변수에서 접속 정보 읽기
# .env 파일 또는 환경변수로 설정:
#   export SMB_HOST=192.168.100.200
#   export SMB_USER=homeshare
#   export SMB_PASS=비밀번호
if [ -f "$(dirname "$0")/.env" ]; then
  source "$(dirname "$0")/.env"
fi

if [ -z "$SMB_HOST" ] || [ -z "$SMB_USER" ] || [ -z "$SMB_PASS" ]; then
  echo "오류: SMB 접속 정보가 설정되지 않았습니다."
  echo ""
  echo "설정 방법: mac-setup/.env 파일 생성"
  echo '  SMB_HOST=192.168.100.200'
  echo '  SMB_USER=아이디'
  echo '  SMB_PASS=비밀번호'
  exit 1
fi

open "smb://${SMB_USER}:${SMB_PASS}@${SMB_HOST}"

echo ""
echo "완료: smb://${SMB_HOST} 연결됨 (계정: ${SMB_USER})"
