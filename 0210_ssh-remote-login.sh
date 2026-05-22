#!/bin/bash
set -e

echo "==> SSH 원격 로그인 활성화 (sshd)"

# 현재 상태 확인
current=$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')

if [ "$current" = "On" ]; then
  echo "Remote Login 이미 켜져 있음"
else
  echo "Remote Login 활성화 중..."
  # 1차: systemsetup (macOS 13+ 에선 호출 터미널의 Full Disk Access 필요)
  out=$(sudo systemsetup -setremotelogin on 2>&1)
  [ -n "$out" ] && echo "  $out"

  # 2차: systemsetup 차단되거나 여전히 Off 면 launchctl 로 직접 부팅
  if echo "$out" | grep -qi "Full Disk Access" \
     || [ "$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')" != "On" ]; then
    echo "  launchctl 로 sshd 활성화 시도"
    sudo launchctl enable system/com.openssh.sshd 2>/dev/null || true
    sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
  fi
fi

# 혹시 disable 되어 있는 경우 대비 (이미 enable 되어 있으면 no-op)
sudo launchctl enable system/com.openssh.sshd 2>/dev/null || true

# 리스닝 확인
echo ""
echo "==> sshd 리스닝 상태"
if sudo lsof -iTCP:22 -sTCP:LISTEN -P 2>/dev/null | grep -q LISTEN; then
  echo "  포트 22 LISTEN 확인됨"
else
  echo "  경고: 포트 22 리스닝 안 됨"
fi

echo ""
echo "==> 접속 정보"
USER_NAME=$(whoami)
LOCAL_HOST=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
TS_IP=$(/opt/homebrew/bin/tailscale ip -4 2>/dev/null \
        || /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null \
        || true)

echo "  사용자       : ${USER_NAME}"
echo "  Bonjour 호스트: ${LOCAL_HOST}.local"
[ -n "$LAN_IP" ] && echo "  LAN IP       : ${LAN_IP}"
[ -n "$TS_IP" ]  && echo "  Tailscale IP : ${TS_IP}"

echo ""
echo "==> 접속 예시"
echo "  ssh ${USER_NAME}@${LOCAL_HOST}.local"
[ -n "$LAN_IP" ] && echo "  ssh ${USER_NAME}@${LAN_IP}"
[ -n "$TS_IP" ]  && echo "  ssh ${USER_NAME}@${TS_IP}"

echo ""
echo "완료: SSH 접속 가능"
echo "※ 처음 접속 시 비밀번호 또는 공개키 인증 필요"
echo "※ 키 등록 예시: ssh-copy-id ${USER_NAME}@${LOCAL_HOST}.local"
