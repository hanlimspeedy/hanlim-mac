#!/bin/bash
set -e

echo "==> /home autofs 해제 + samba 링크 + Finder 디스크 표시 + 즐겨찾기"

# 1. autofs /home 비활성화 (NFS 자동 마운트 안 쓰면 무해)
#    /home 아래에 일반 디렉토리/심볼릭 링크를 만들 수 있게 됨
if grep -qE '^/home' /etc/auto_master 2>/dev/null; then
  echo "  - /etc/auto_master 의 /home 자동 마운트 항목 주석 처리"
  sudo sed -i '' 's|^/home|#/home|' /etc/auto_master
  sudo automount -vc >/dev/null
else
  echo "  - /etc/auto_master 의 /home 항목 이미 비활성화됨"
fi

# 2. /home/ubuntu/root -> samba 마운트 심볼릭 링크
#    리눅스 서버와 동일한 경로로 접근 가능 (/home/ubuntu/root)
SMB_MOUNT="/Volumes/ubuntu/root"
LINK_PATH="/home/ubuntu/root"

if [ ! -d "$SMB_MOUNT" ]; then
  echo "  ! 경고: ${SMB_MOUNT} 가 마운트되지 않음. 1300_smb-connect.sh 먼저 실행 필요"
fi

sudo mkdir -p /home/ubuntu
if [ -L "$LINK_PATH" ]; then
  echo "  - ${LINK_PATH} 심볼릭 링크 이미 존재"
else
  sudo ln -s "$SMB_MOUNT" "$LINK_PATH"
  echo "  - ${LINK_PATH} -> ${SMB_MOUNT} 생성"
fi

# 3. Finder 데스크톱/사이드바에 모든 디스크 표시
echo "  - Finder 디스크 표시 활성화 (HDD/외장/이동식/마운트 서버)"
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true

# 4. /home/ubuntu Finder 사이드바 즐겨찾기 추가 (mysides 사용)
if ! command -v mysides >/dev/null 2>&1; then
  echo "  - mysides 설치 (Finder 사이드바 관리 CLI)"
  brew install mysides
fi

if mysides list 2>/dev/null | grep -q "file:///home/ubuntu/"; then
  echo "  - /home/ubuntu 즐겨찾기 이미 등록됨"
else
  mysides add "ubuntu (samba)" "file:///home/ubuntu/"
  echo "  - Finder 사이드바 즐겨찾기에 /home/ubuntu 추가"
fi

# 5. Finder 재시작 (변경 적용)
killall Finder 2>/dev/null || true

echo ""
echo "완료: /home/ubuntu/root 접근 가능 + Finder 사이드바 즐겨찾기 등록"
