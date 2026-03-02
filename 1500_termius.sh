#!/bin/bash
set -e

echo "==> Termius 설치 (SSH 클라이언트)"

if brew list --cask termius &>/dev/null; then
  echo "이미 설치됨: $(brew info --cask termius | head -1)"
else
  brew install --cask termius
fi

echo ""
echo "완료: Termius 설치됨"
echo "  - SSH/SFTP 클라이언트"
echo "  - 서버 관리, 세션 복제 지원"
echo ""
echo "※ 실행: open -a Termius"
