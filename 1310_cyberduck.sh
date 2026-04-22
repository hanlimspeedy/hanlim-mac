#!/bin/bash
set -e

echo "==> Cyberduck 설치 (FTP/SFTP/WebDAV/S3 GUI 클라이언트)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask cyberduck &>/dev/null; then
  echo "Cyberduck 설치 중..."
  brew install --cask cyberduck
else
  echo "Cyberduck 이미 설치됨"
fi

echo ""
echo "완료: Cyberduck 설치됨"
echo "  - FTP / SFTP / WebDAV / S3 / Google Drive / Dropbox 등 지원"
echo "  - 오픈소스 무료 (Mac App Store 버전은 유료)"
echo "  - Finder 스타일 GUI, 북마크/동기화 지원"
echo ""
echo "※ https://cyberduck.io/"
