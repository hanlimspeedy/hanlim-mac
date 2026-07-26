#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
ACTION="${1:-on}"
TARGET_USER=""
PASSWORD_FILE=""
VNC_PASSWORD_VALUE=""

usage() {
  echo "사용법: $0 [on|off|status] [--user macOS계정] [--password-file 파일]"
  echo ""
  echo "  on      (기본) — macOS 내장 VNC 서버 켜기 + Windows 접속 정보 출력"
  echo "  off              — VNC 암호 접속 비활성화 + 서버 끄기"
  echo "  status           — 서버, TCP 5900, 접속 주소 상태 확인"
  echo "  --user 계정      — 원격 제어를 허용할 로컬 macOS 계정 지정"
  echo "  --password-file  — 권한 600인 파일에서 VNC 암호 읽기 (자동화용)"
  echo ""
  echo "예:"
  echo "  $0"
  echo "  $0 on --user \"$(id -un)\""
  echo "  $0 on --password-file .vnc-passwd.env"
  echo "  $0 status"
  echo "  $0 off"
}

case "$ACTION" in
  on|--on|enable)
    ACTION=on
    shift
    ;;
  off|--off|disable)
    ACTION=off
    shift
    ;;
  status|--status)
    ACTION=status
    shift
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "오류: 알 수 없는 동작: $ACTION"
    echo ""
    usage
    exit 1
    ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --user 뒤에 macOS 계정을 입력하세요."
        exit 1
      fi
      TARGET_USER="$2"
      shift 2
      ;;
    --password-file)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --password-file 뒤에 파일 경로를 입력하세요."
        exit 1
      fi
      PASSWORD_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "오류: 알 수 없는 인자: $1"
      echo ""
      usage
      exit 1
      ;;
  esac
done

if [ "$ACTION" != "on" ] && [ -n "$PASSWORD_FILE" ]; then
  echo "오류: --password-file은 on 동작에서만 사용할 수 있습니다."
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

if [ ! -x "$KICKSTART" ]; then
  echo "오류: macOS 내장 Remote Management 도구를 찾을 수 없습니다."
  echo "  경로: $KICKSTART"
  exit 1
fi

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

get_default_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  local current_user
  current_user=$(id -un)
  if [ "$current_user" != "root" ]; then
    printf '%s\n' "$current_user"
    return
  fi

  stat -f '%Su' /dev/console
}

get_lan_ip() {
  local default_interface
  default_interface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')

  if [ -n "$default_interface" ]; then
    ipconfig getifaddr "$default_interface" 2>/dev/null || true
  else
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
  fi
}

get_tailscale_ip() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale ip -4 2>/dev/null | head -1 || true
  elif [ -x /opt/homebrew/bin/tailscale ]; then
    /opt/homebrew/bin/tailscale ip -4 2>/dev/null | head -1 || true
  elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
    /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null | head -1 || true
  fi
}

service_is_loaded() {
  launchctl print system/com.apple.screensharing >/dev/null 2>&1
}

port_is_listening() {
  if command -v nc >/dev/null 2>&1; then
    nc -z -G 1 127.0.0.1 5900 >/dev/null 2>&1
  else
    lsof -nP -iTCP:5900 -sTCP:LISTEN >/dev/null 2>&1
  fi
}

legacy_vnc_is_enabled() {
  local value
  value=$(defaults read /Library/Preferences/com.apple.RemoteManagement \
    VNCLegacyConnectionsEnabled 2>/dev/null || true)
  [ "$value" = "1" ] || [ "$value" = "true" ]
}

validate_vnc_password() {
  local password_length
  password_length=${#VNC_PASSWORD_VALUE}

  if [ "$password_length" -lt 6 ] || [ "$password_length" -gt 8 ]; then
    echo "오류: VNC 암호는 ASCII 문자 6~8자로 입력하세요."
    return 1
  fi

  case "$VNC_PASSWORD_VALUE" in
    *[![:graph:]]*)
      echo "오류: 공백이나 한글 없이 ASCII 영문/숫자/기호만 사용하세요."
      return 1
      ;;
    -*)
      echo "오류: 암호의 첫 글자로 '-'는 사용할 수 없습니다."
      return 1
      ;;
  esac

  if [ "$password_length" -lt 8 ]; then
    echo "경고: ${password_length}자 암호입니다. 가능하면 8자를 권장합니다."
  fi
}

read_password_file() {
  local file_mode file_owner_uid caller_uid line_count first_line

  if [ -L "$PASSWORD_FILE" ]; then
    echo "오류: 암호 파일로 심볼릭 링크를 사용할 수 없습니다."
    return 1
  fi

  if [ ! -f "$PASSWORD_FILE" ]; then
    echo "오류: 암호 파일을 찾을 수 없거나 일반 파일이 아닙니다: $PASSWORD_FILE"
    return 1
  fi

  file_mode=$(stat -f '%Lp' "$PASSWORD_FILE")
  file_owner_uid=$(stat -f '%u' "$PASSWORD_FILE")
  if [ -n "${SUDO_UID:-}" ]; then
    caller_uid=$SUDO_UID
  elif [ "$(id -u)" -eq 0 ] && [ -n "$TARGET_USER" ]; then
    caller_uid=$(id -u "$TARGET_USER")
  else
    caller_uid=$(id -u)
  fi
  line_count=$(awk 'END {print NR}' "$PASSWORD_FILE")

  if [ "$file_mode" != "600" ]; then
    echo "오류: 암호 파일 권한은 600이어야 합니다. 현재 권한: $file_mode"
    echo "  chmod 600 \"$PASSWORD_FILE\""
    return 1
  fi

  if [ "$file_owner_uid" != "$caller_uid" ]; then
    echo "오류: 암호 파일이 현재 실행 사용자의 소유가 아닙니다."
    return 1
  fi

  if [ "$line_count" -ne 1 ]; then
    echo "오류: 암호 파일에는 한 줄만 있어야 합니다."
    return 1
  fi

  first_line=""
  IFS= read -r first_line < "$PASSWORD_FILE" || true

  case "$first_line" in
    VNC_PASSWORD=*) VNC_PASSWORD_VALUE=${first_line#VNC_PASSWORD=} ;;
    *) VNC_PASSWORD_VALUE=$first_line ;;
  esac

  validate_vnc_password
}

print_status() {
  local local_host lan_ip tailscale_ip
  local_host=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
  lan_ip=$(get_lan_ip)
  tailscale_ip=$(get_tailscale_ip)

  echo "────────────────────────────────────────────────────────"
  echo " macOS VNC 서버 상태"
  echo "────────────────────────────────────────────────────────"

  if service_is_loaded; then
    echo "  화면 공유 서비스 : 켜짐"
  else
    echo "  화면 공유 서비스 : 꺼짐"
  fi

  if legacy_vnc_is_enabled; then
    echo "  Windows VNC 암호 : 사용"
  else
    echo "  Windows VNC 암호 : 사용 안 함"
  fi

  if port_is_listening; then
    echo "  TCP 5900        : LISTEN"
  else
    echo "  TCP 5900        : LISTEN 확인 안 됨"
  fi

  echo ""
  echo "  Bonjour 호스트  : ${local_host}.local"
  [ -n "$lan_ip" ] && echo "  LAN IP          : ${lan_ip}"
  [ -n "$tailscale_ip" ] && echo "  Tailscale IP    : ${tailscale_ip}"
  echo "────────────────────────────────────────────────────────"
}

if [ "$ACTION" = "status" ]; then
  print_status
  exit 0
fi

echo "==> 관리자 권한 확인"
if [ "$(id -u)" -ne 0 ]; then
  sudo -v
fi

if [ "$ACTION" = "off" ]; then
  echo "==> macOS 내장 VNC 서버 끄기"

  run_as_root "$KICKSTART" \
    -deactivate \
    -configure \
      -clientopts \
        -setvnclegacy -vnclegacy no \
    -stop \
    -quiet

  sleep 1
  echo ""
  print_status
  echo ""

  if service_is_loaded || legacy_vnc_is_enabled; then
    echo "오류: VNC 설정이 완전히 꺼지지 않았습니다."
    echo "시스템 설정 → 일반 → 공유에서 원격 관리를 직접 꺼주세요."
    exit 2
  fi

  echo "완료: VNC 암호 접속과 화면 공유 서비스를 껐습니다."
  echo "참고: 기존 암호 파일과 사용자 권한 설정은 보존됩니다."
  exit 0
fi

if [ -z "$TARGET_USER" ]; then
  TARGET_USER=$(get_default_user)
fi

if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "오류: 원격 제어를 허용할 일반 macOS 계정을 찾지 못했습니다."
  echo "  예: $0 on --user 사용자이름"
  exit 1
fi

if ! dscl . -read "/Users/$TARGET_USER" >/dev/null 2>&1; then
  echo "오류: 로컬 macOS 계정이 아닙니다: $TARGET_USER"
  exit 1
fi

echo "==> macOS 내장 VNC 서버 켜기"
echo "  허용 계정: $TARGET_USER"
echo ""
echo "VNC 암호는 Apple 호환 규격상 ASCII 6~8자를 사용합니다 (8자 권장)."

if [ -n "$PASSWORD_FILE" ]; then
  echo "  암호 파일: $PASSWORD_FILE (내용은 출력하지 않음)"
  read_password_file
else
  while true; do
    IFS= read -r -s -p "VNC 암호 입력 (6~8자, 8자 권장): " VNC_PASSWORD_VALUE
    echo ""

    if ! validate_vnc_password; then
      continue
    fi

    IFS= read -r -s -p "VNC 암호 확인: " VNC_PASSWORD_CONFIRM
    echo ""

    if [ "$VNC_PASSWORD_VALUE" != "$VNC_PASSWORD_CONFIRM" ]; then
      echo "오류: 암호가 일치하지 않습니다."
      VNC_PASSWORD_CONFIRM=""
      continue
    fi

    VNC_PASSWORD_CONFIRM=""
    break
  done
fi

trap 'VNC_PASSWORD_VALUE=""; VNC_PASSWORD_CONFIRM=""' EXIT

# 현재 Tahoe의 kickstart는 화면 공유 서비스를 먼저 활성화한 뒤
# RemoteManagement.launchd 표시 파일 생성에서 실패할 수 있다. 서비스가 실제로
# 로드됐다면 구성 단계를 별도 호출하여 계속 진행한다.
if ! service_is_loaded; then
  if ! run_as_root "$KICKSTART" -activate -quiet; then
    if service_is_loaded; then
      echo "경고: kickstart 활성화 표시 파일 생성은 실패했지만 화면 공유 서비스는 켜졌습니다."
      echo "  VNC 구성 단계를 계속합니다."
    else
      echo "오류: 화면 공유 서비스를 활성화하지 못했습니다."
      exit 2
    fi
  fi
fi

# kickstart는 -allowAccessFor와 -privs를 같은 호출에 넣으면 -privs를 무시한다.
# 접근 범위와 사용자 제어 권한을 별도 호출로 설정한다.
run_as_root "$KICKSTART" \
  -configure \
    -allowAccessFor -specifiedUsers \
  -quiet

# kickstart는 VNC 암호를 인자로 받지만, 그러면 ps 출력에 암호가 잠시 노출된다.
# 표준 입력으로 root 셸에 전달한 뒤 kickstart가 지원하는 CO_VNCPW 환경변수로 넘긴다.
if [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' "$VNC_PASSWORD_VALUE" | /bin/sh -c '
    IFS= read -r CO_VNCPW || exit 1
    export CO_VNCPW
    exec "$@"
  ' sh "$KICKSTART" \
    -configure \
      -users "$TARGET_USER" \
      -access -on \
      -privs -ControlObserve \
      -clientopts \
        -setreqperm -reqperm no \
        -setvnclegacy -vnclegacy yes \
        -setvncpw \
    -restart -agent \
    -quiet
else
  printf '%s\n' "$VNC_PASSWORD_VALUE" | sudo /bin/sh -c '
    IFS= read -r CO_VNCPW || exit 1
    export CO_VNCPW
    exec "$@"
  ' sh "$KICKSTART" \
    -configure \
      -users "$TARGET_USER" \
      -access -on \
      -privs -ControlObserve \
      -clientopts \
        -setreqperm -reqperm no \
        -setvnclegacy -vnclegacy yes \
        -setvncpw \
    -restart -agent \
    -quiet
fi

VNC_PASSWORD_VALUE=""

sleep 1
echo ""
print_status
echo ""

if ! service_is_loaded || ! legacy_vnc_is_enabled; then
  echo "오류: VNC 서비스 또는 암호 인증을 활성화하지 못했습니다."
  echo "시스템 설정 → 일반 → 공유에서 원격 관리를 켠 뒤 다시 실행하세요."
  exit 2
fi

echo "완료: macOS 내장 VNC 서버를 켰습니다."
echo "  - Windows: TigerVNC Viewer에서 위 LAN 또는 Tailscale IP로 접속"
echo "  - 포트: 5900 (Viewer에는 보통 IP 주소만 입력)"
echo "  - 끄기: $0 off"
echo ""
echo "중요: 공유기에서 TCP 5900 포트 포워딩을 하지 마세요."
echo "외부망에서는 양쪽 기기에 Tailscale을 설치하고 Tailscale IP를 사용하세요."
echo ""
echo "마우스/키보드 제어가 안 되고 보기만 가능하면 macOS 보안 승인이 필요합니다."
echo "시스템 설정 → 일반 → 공유 → 원격 관리에서 한 번 껐다 켠 뒤 권한을 확인하세요."
echo "상세 안내: $(dirname "$0")/config/VNC.md"
