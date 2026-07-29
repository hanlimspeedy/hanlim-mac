#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

APP_PATH="/Applications/RustDesk.app"
SERVICE_LABEL="com.carriez.RustDesk_service"
SERVER_LABEL="com.carriez.RustDesk_server"
SERVICE_PLIST="/Library/LaunchDaemons/${SERVICE_LABEL}.plist"
SERVER_PLIST="/Library/LaunchAgents/${SERVER_LABEL}.plist"
ACTION="${1:-on}"
TARGET_USER=""
TEMP_DIR=""

usage() {
  echo "사용법: $0 [on|off|status] [--user macOS계정]"
  echo ""
  echo "  on      (기본) — RustDesk 부팅/로그인 자동 실행 설치"
  echo "  off              — 자동 실행 서비스 제거 (앱과 설정은 보존)"
  echo "  status           — launchd 등록 및 실행 상태 확인"
  echo "  --user 계정      — RustDesk GUI 서버를 실행할 로컬 계정"
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

if [ "$(uname -s)" != "Darwin" ]; then
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

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

  scutil <<'EOF' | awk '/Name :/ {print $3; exit}'
show State:/Users/ConsoleUser
EOF
}

if [ -z "$TARGET_USER" ]; then
  TARGET_USER=$(get_default_user)
fi

if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "오류: RustDesk를 실행할 일반 macOS 계정을 찾지 못했습니다."
  echo "  예: $0 on --user 사용자이름"
  exit 1
fi

if ! dscl . -read "/Users/$TARGET_USER" >/dev/null 2>&1; then
  echo "오류: 로컬 macOS 계정이 아닙니다: $TARGET_USER"
  exit 1
fi

TARGET_UID=$(id -u "$TARGET_USER")
TARGET_HOME=$(
  dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory |
    awk -F': ' '/NFSHomeDirectory:/ {print $2; exit}'
)
GUI_DOMAIN="gui/${TARGET_UID}"

service_is_loaded() {
  sudo launchctl print "system/${SERVICE_LABEL}" >/dev/null 2>&1
}

server_is_loaded() {
  sudo launchctl print "${GUI_DOMAIN}/${SERVER_LABEL}" >/dev/null 2>&1
}

gui_domain_is_available() {
  sudo launchctl print "$GUI_DOMAIN" >/dev/null 2>&1
}

print_status() {
  echo "────────────────────────────────────────────────────────"
  echo " RustDesk 자동 실행 상태"
  echo "────────────────────────────────────────────────────────"
  echo "  대상 계정       : $TARGET_USER (UID $TARGET_UID)"

  if [ -f "$SERVICE_PLIST" ]; then
    echo "  부팅 서비스 파일: 설치됨"
  else
    echo "  부팅 서비스 파일: 없음"
  fi

  if service_is_loaded; then
    local service_pid
    service_pid=$(
      sudo launchctl print "system/${SERVICE_LABEL}" |
        awk '/^[[:space:]]*pid =/ {print $3; exit}'
    )
    echo "  부팅 서비스     : 실행 중 (PID ${service_pid:-확인 안 됨})"
  else
    echo "  부팅 서비스     : 실행 안 됨"
  fi

  if [ -f "$SERVER_PLIST" ]; then
    echo "  로그인 서버 파일: 설치됨"
  else
    echo "  로그인 서버 파일: 없음"
  fi

  if server_is_loaded; then
    local server_pid
    server_pid=$(
      sudo launchctl print "${GUI_DOMAIN}/${SERVER_LABEL}" |
        awk '/^[[:space:]]*pid =/ {print $3; exit}'
    )
    echo "  로그인 서버     : 실행 중 (PID ${server_pid:-확인 안 됨})"
  elif gui_domain_is_available; then
    echo "  로그인 서버     : 실행 안 됨"
  else
    echo "  로그인 서버     : GUI 세션 로그인 후 시작 예정"
  fi

  echo "────────────────────────────────────────────────────────"
}

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

if [ "$ACTION" = "status" ]; then
  print_status
  exit 0
fi

echo "==> 관리자 권한 확인"
sudo true

if [ "$ACTION" = "off" ]; then
  echo "==> RustDesk 자동 실행 끄기"

  if server_is_loaded; then
    sudo launchctl bootout "${GUI_DOMAIN}/${SERVER_LABEL}"
  fi
  sudo launchctl disable "${GUI_DOMAIN}/${SERVER_LABEL}" 2>/dev/null || true

  if service_is_loaded; then
    sudo launchctl bootout "system/${SERVICE_LABEL}"
  fi
  sudo launchctl disable "system/${SERVICE_LABEL}" 2>/dev/null || true

  sudo rm -f "$SERVER_PLIST" "$SERVICE_PLIST"

  echo ""
  print_status
  echo ""
  echo "완료: RustDesk 자동 실행을 제거했습니다."
  echo "참고: RustDesk 앱과 사용자 설정은 보존됩니다."
  exit 0
fi

if [ ! -x "$APP_PATH/Contents/MacOS/RustDesk" ] ||
  [ ! -x "$APP_PATH/Contents/MacOS/service" ]; then
  echo "오류: RustDesk가 /Applications에 설치되어 있지 않습니다."
  echo "먼저 ./1360_rustdesk.sh 를 실행하세요."
  exit 1
fi

echo "==> RustDesk 부팅/로그인 자동 실행 설치"
echo "  대상 계정: $TARGET_USER"

TEMP_DIR=$(mktemp -d /tmp/rustdesk-autostart.XXXXXX)
trap cleanup EXIT

cat >"$TEMP_DIR/${SERVICE_LABEL}.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.carriez.RustDesk_service</string>
    <key>AssociatedBundleIdentifiers</key>
    <string>com.carriez.rustdesk</string>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>1</integer>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string>
      <string>-c</string>
      <string>/Applications/RustDesk.app/Contents/MacOS/service</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Applications/RustDesk.app/Contents/MacOS/</string>
    <key>StandardErrorPath</key>
    <string>/tmp/rustdesk_service.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/rustdesk_service.out</string>
  </dict>
</plist>
PLIST

cat >"$TEMP_DIR/${SERVER_LABEL}.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.carriez.RustDesk_server</string>
    <key>AssociatedBundleIdentifiers</key>
    <string>com.carriez.rustdesk</string>
    <key>LimitLoadToSessionType</key>
    <array>
      <string>LoginWindow</string>
      <string>Aqua</string>
    </array>
    <key>KeepAlive</key>
    <dict>
      <key>SuccessfulExit</key>
      <false/>
      <key>AfterInitialDemand</key>
      <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>1</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>ProgramArguments</key>
    <array>
      <string>/Applications/RustDesk.app/Contents/MacOS/RustDesk</string>
      <string>--server</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Applications/RustDesk.app/Contents/MacOS/</string>
    <key>ProcessType</key>
    <string>Interactive</string>
  </dict>
</plist>
PLIST

plutil -lint \
  "$TEMP_DIR/${SERVICE_LABEL}.plist" \
  "$TEMP_DIR/${SERVER_LABEL}.plist"

sudo install -o root -g wheel -m 644 \
  "$TEMP_DIR/${SERVICE_LABEL}.plist" \
  "$SERVICE_PLIST"
sudo install -o root -g wheel -m 644 \
  "$TEMP_DIR/${SERVER_LABEL}.plist" \
  "$SERVER_PLIST"

ROOT_PREFS="/var/root/Library/Preferences/com.carriez.RustDesk"
USER_PREFS="${TARGET_HOME}/Library/Preferences/com.carriez.RustDesk"
sudo mkdir -p "$ROOT_PREFS"

for config_name in RustDesk.toml RustDesk2.toml; do
  if [ -f "$USER_PREFS/$config_name" ]; then
    sudo install -o root -g wheel -m 600 \
      "$USER_PREFS/$config_name" \
      "$ROOT_PREFS/$config_name"
  fi
done

if service_is_loaded; then
  sudo launchctl bootout "system/${SERVICE_LABEL}"
fi
sudo launchctl enable "system/${SERVICE_LABEL}"
sudo launchctl bootstrap system "$SERVICE_PLIST"

if gui_domain_is_available; then
  if server_is_loaded; then
    sudo launchctl bootout "${GUI_DOMAIN}/${SERVER_LABEL}"
  fi
  sudo launchctl enable "${GUI_DOMAIN}/${SERVER_LABEL}"
  sudo launchctl bootstrap "$GUI_DOMAIN" "$SERVER_PLIST"
  sudo launchctl kickstart -k "${GUI_DOMAIN}/${SERVER_LABEL}"
else
  echo "  현재 GUI 세션이 없어 로그인 시 RustDesk 서버가 시작됩니다."
fi

sleep 2
echo ""
print_status
echo ""

if ! service_is_loaded; then
  echo "오류: RustDesk 부팅 서비스를 시작하지 못했습니다."
  exit 2
fi

if gui_domain_is_available && ! server_is_loaded; then
  echo "오류: RustDesk 로그인 서버를 시작하지 못했습니다."
  exit 2
fi

echo "완료: RustDesk가 부팅 및 로그인 시 자동 실행됩니다."
echo "  - daemon: Mac 부팅 시 시작, 종료되면 자동 재시작"
echo "  - server: 로그인 화면/Aqua 세션에서 시작, 비정상 종료 시 자동 재시작"
echo ""
echo "macOS 개인정보 보호 권한은 최초 한 번 직접 승인해야 합니다."
echo "  화면 및 시스템 오디오 녹음 / 손쉬운 사용 / 필요 시 입력 모니터링"
