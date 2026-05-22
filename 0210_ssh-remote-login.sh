#!/bin/bash
set -e

ACTION="${1:-on}"

case "$ACTION" in
  on|--on|enable) ACTION=on ;;
  off|--off|disable) ACTION=off ;;
  -h|--help|help)
    echo "사용법: $0 [on|off]"
    echo "  on  (기본) — SSH 원격 로그인 켜기 + 접속 정보 출력"
    echo "  off        — SSH 원격 로그인 끄기 (sshd 종료)"
    exit 0
    ;;
  *)
    echo "알 수 없는 인자: $ACTION"
    echo "사용법: $0 [on|off]"
    exit 1
    ;;
esac

current=$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')

if [ "$ACTION" = "off" ]; then
  echo "==> SSH 원격 로그인 끄기 (sshd)"

  if [ "$current" = "Off" ]; then
    echo "Remote Login 이미 꺼져 있음"
  else
    echo "Remote Login 비활성화 중..."
    # 1차: systemsetup -f -setremotelogin off (-f 는 명령 앞, 확인 프롬프트 우회)
    # FDA 부족 시 비제로 종료하므로 || true 로 set -e 우회
    out=$(sudo systemsetup -f -setremotelogin off 2>&1 || true)
    [ -n "$out" ] && echo "  $out"

    # 2차: 차단되거나 여전히 On 이면 launchctl 로 직접 stop
    if echo "$out" | grep -qi "Full Disk Access" \
       || [ "$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')" != "Off" ]; then
      echo "  launchctl 로 sshd 종료 시도"
      sudo launchctl bootout system/com.openssh.sshd 2>/dev/null || true
      sudo launchctl disable system/com.openssh.sshd 2>/dev/null || true
    fi
  fi

  echo ""
  echo "==> sshd 리스닝 상태"
  if sudo lsof -iTCP:22 -sTCP:LISTEN -P 2>/dev/null | grep -q LISTEN; then
    echo "  경고: 포트 22 아직 LISTEN 중 — Full Disk Access 권한 부여 후 재시도 필요할 수 있음"
    echo "  시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한 → 사용 중인 터미널 추가"
  else
    echo "  포트 22 LISTEN 종료됨"
  fi

  echo ""
  echo "완료: SSH 접속 차단됨"
  exit 0
fi

# ────── 여기부터 ON 경로 ──────
echo "==> SSH 원격 로그인 활성화 (sshd)"

if [ "$current" = "On" ]; then
  echo "Remote Login 이미 켜져 있음"
else
  echo "Remote Login 활성화 중..."
  # 1차: systemsetup (macOS 13+ 에선 호출 터미널의 Full Disk Access 필요)
  # FDA 부족 시 비제로 종료하므로 || true 로 set -e 우회
  out=$(sudo systemsetup -setremotelogin on 2>&1 || true)
  [ -n "$out" ] && echo "  $out"

  # 2차: 차단되거나 여전히 Off 면 launchctl 로 직접 부팅
  if echo "$out" | grep -qi "Full Disk Access" \
     || [ "$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')" != "On" ]; then
    echo "  launchctl 로 sshd 활성화 시도"
    sudo launchctl enable system/com.openssh.sshd 2>/dev/null || true
    sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
  fi
fi

# 혹시 disable 되어 있는 경우 대비 (이미 enable 되어 있으면 no-op)
sudo launchctl enable system/com.openssh.sshd 2>/dev/null || true

echo ""
echo "==> sshd 리스닝 상태"
if sudo lsof -iTCP:22 -sTCP:LISTEN -P 2>/dev/null | grep -q LISTEN; then
  echo "  포트 22 LISTEN 확인됨"
else
  echo "  경고: 포트 22 리스닝 안 됨"
fi

USER_NAME=$(whoami)
LOCAL_HOST=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
TS_IP=$(/opt/homebrew/bin/tailscale ip -4 2>/dev/null \
        || /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null \
        || true)

echo ""
echo "────────────────────────────────────────────────────────"
echo " SSH 접속 정보"
echo "────────────────────────────────────────────────────────"
echo "  계정          : ${USER_NAME}"
echo "  비밀번호      : 이 맥의 macOS 로그인 비밀번호 그대로"
echo "  Bonjour 호스트: ${LOCAL_HOST}.local"
[ -n "$LAN_IP" ] && echo "  LAN IP        : ${LAN_IP}"
[ -n "$TS_IP" ]  && echo "  Tailscale IP  : ${TS_IP}"
echo ""
echo " 다른 기기에서 접속 (셋 중 하나):"
echo ""
echo "  # 같은 와이파이/LAN 안 (이름)"
echo "  ssh ${USER_NAME}@${LOCAL_HOST}.local"
[ -n "$LAN_IP" ] && echo ""
[ -n "$LAN_IP" ] && echo "  # 같은 와이파이/LAN 안 (IP, 이름 해석 실패시)"
[ -n "$LAN_IP" ] && echo "  ssh ${USER_NAME}@${LAN_IP}"
[ -n "$TS_IP" ]  && echo ""
[ -n "$TS_IP" ]  && echo "  # 외부망 (Tailscale 켠 다른 기기에서)"
[ -n "$TS_IP" ]  && echo "  ssh ${USER_NAME}@${TS_IP}"
echo ""
echo " 처음 접속 시:"
echo "  - 'Are you sure you want to continue connecting?' → yes"
echo "  - 'Password:' 프롬프트에 macOS 로그인 비밀번호 입력"
echo ""
echo " (선택) 비밀번호 매번 안 묻게 공개키 등록 — 클라이언트 쪽에서 1회:"
echo "  ssh-copy-id ${USER_NAME}@${LOCAL_HOST}.local"
echo ""
echo " 끄기: $0 off"
echo "────────────────────────────────────────────────────────"
