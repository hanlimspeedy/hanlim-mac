#!/bin/bash
set -e

echo "==> SSH 원격 로그인 활성화 (sshd)"

# 현재 상태 확인
current=$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')

if [ "$current" = "On" ]; then
  echo "Remote Login 이미 켜져 있음"
else
  echo "Remote Login 활성화 중..."
  # 10.13+ 부터 -f 로 TCC 프롬프트 우회 (Full Disk Access 필요할 수 있음)
  sudo systemsetup -setremotelogin on -f 2>/dev/null || sudo systemsetup -setremotelogin on
fi

# sshd LaunchDaemon 강제 활성화 (혹시 disable 되어 있을 경우 대비)
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
