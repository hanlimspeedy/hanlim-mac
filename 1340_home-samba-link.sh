#!/bin/bash
set -e

echo "==> /home autofs 해제 + /home synthetic 링크 + samba 즐겨찾기"

# 1. autofs /home 비활성화 (NFS 자동 마운트 안 쓰면 무해)
if grep -qE '^/home' /etc/auto_master 2>/dev/null; then
  echo "  - /etc/auto_master 의 /home 자동 마운트 항목 주석 처리"
  sudo sed -i '' 's|^/home|#/home|' /etc/auto_master
  sudo automount -vc >/dev/null
else
  echo "  - /etc/auto_master 의 /home 항목 이미 비활성화됨"
fi

# 2. /etc/synthetic.conf 에 /home -> /System/Volumes/Data/home 심볼릭 링크 추가
#    macOS SSV(read-only 시스템 볼륨)에서는 루트(/)에 디렉토리를 직접 만들 수 없음.
#    synthetic.conf 가 루트 레벨 심볼릭 링크/디렉토리를 합성해 주는 표준 방법.
#    데이터 볼륨(/System/Volumes/Data)은 쓰기 가능하므로
#    /home 을 그쪽으로 보내면 /home/ubuntu 디렉토리와 그 하위 심볼릭 링크를 자유롭게 관리 가능.
SYNTHETIC_TARGET="/System/Volumes/Data/home"
EXPECTED_LINE=$(printf 'home\t%s' "$SYNTHETIC_TARGET")
SYNTHETIC_CHANGED=0
if [ -f /etc/synthetic.conf ] && grep -qxF "$EXPECTED_LINE" /etc/synthetic.conf; then
  echo "  - /etc/synthetic.conf 에 home -> ${SYNTHETIC_TARGET} 항목 이미 존재"
else
  # 잘못된 home 항목이 있으면 제거 후 재작성
  if [ -f /etc/synthetic.conf ] && grep -qE '^home[[:space:]]' /etc/synthetic.conf; then
    echo "  - /etc/synthetic.conf 의 기존 home 항목 제거 (타겟 갱신)"
    sudo sed -i '' '/^home[[:space:]]/d' /etc/synthetic.conf
  fi
  echo "  - /etc/synthetic.conf 에 home -> ${SYNTHETIC_TARGET} 항목 추가"
  printf 'home\t%s\n' "$SYNTHETIC_TARGET" | sudo tee -a /etc/synthetic.conf >/dev/null
  SYNTHETIC_CHANGED=1
fi

# 3. synthetic.conf 즉시 적용 (재부팅 없이 /home 심볼릭 링크 활성화)
#    apfs.util -t : "stitches and creates synthetic objects on root volume group"
if [ ! -L /home ] || [ "$(readlink /home)" != "$SYNTHETIC_TARGET" ] || [ "$SYNTHETIC_CHANGED" = "1" ]; then
  echo "  - apfs.util -t 로 synthetic 링크 즉시 적용"
  sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t
fi

# 4. /System/Volumes/Data/home/ubuntu/root -> samba 마운트 심볼릭 링크
SMB_MOUNT="/Volumes/ubuntu/root"
DATA_HOME_UBUNTU="${SYNTHETIC_TARGET}/ubuntu"
LINK_PATH="${DATA_HOME_UBUNTU}/root"

if [ ! -d "$SMB_MOUNT" ]; then
  echo "  ! 경고: ${SMB_MOUNT} 가 마운트되지 않음. 1300_smb-connect.sh 먼저 실행 필요"
fi

sudo mkdir -p "$DATA_HOME_UBUNTU"
if [ -L "$LINK_PATH" ]; then
  echo "  - ${LINK_PATH} 심볼릭 링크 이미 존재"
else
  sudo ln -s "$SMB_MOUNT" "$LINK_PATH"
  echo "  - ${LINK_PATH} -> ${SMB_MOUNT} 생성"
fi

# 5. mysides 설치 (Finder 사이드바 관리 CLI)
if ! command -v mysides >/dev/null 2>&1; then
  echo "  - mysides 설치"
  brew install mysides
fi

# Apple Silicon: mysides 가 x86_64 바이너리이므로 Rosetta 2 필요
if [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  echo "  - Rosetta 2 설치 (mysides x86_64 바이너리 실행용)"
  sudo softwareupdate --install-rosetta --agree-to-license
fi

# 6. /home/ubuntu Finder 사이드바 즐겨찾기 등록
#    macOS 가 심볼릭 링크를 정규화해 file:///System/Volumes/Data/home/ubuntu/ 로 저장하지만
#    표시/네비게이션은 정상 동작.
FAVORITE_NAME="ubuntu (samba)"
if mysides list 2>/dev/null | grep -qE '^ubuntu \(samba\) -> file:///(System/Volumes/Data/)?home/ubuntu/?$'; then
  echo "  - ${FAVORITE_NAME} 즐겨찾기 이미 등록됨"
else
  # 다른 경로로 등록된 stale 항목이 있으면 제거
  mysides remove "$FAVORITE_NAME" 2>/dev/null || true
  mysides add "$FAVORITE_NAME" "file:///home/ubuntu/"
  echo "  - Finder 사이드바 즐겨찾기 등록: ${FAVORITE_NAME} -> /home/ubuntu/"
fi

# 7. Finder 재시작 (사이드바 변경 적용)
killall Finder 2>/dev/null || true

echo ""
echo "완료: /home/ubuntu/root 접근 가능 + Finder 사이드바 즐겨찾기 등록"
