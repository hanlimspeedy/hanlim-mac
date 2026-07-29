#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEST_SCRIPT="${SCRIPT_DIR}/0211_ssh-remote-login-test.sh"
SSHD_ACCESS_CONFIG="/etc/ssh/sshd_config.d/99-mac-sshd-allowlist.conf"
SSHD_BACKUP_DIR="/var/backups/hanlim-mac"

ACTION="${1:-on}"
TARGET_USER=""
RUN_TEST=1
ALLOW_ANY_HOST=0

usage() {
  echo "사용법: $0 [on|off|status] [--user macOS계정] [--allow-any-host] [--skip-test]"
  echo ""
  echo "  on        (기본) — SSH 원격 로그인 켜기 + 실제 공개키 인증 테스트"
  echo "  off                — SSH 원격 로그인 끄기"
  echo "  status             — 설정, 접근 권한, 서비스와 TCP 22 상태 확인"
  echo "  --user 계정        — SSH 접근을 확인할 로컬 macOS 계정"
  echo "  --allow-any-host    — 지정 사용자의 접속 원본 IP/호스트 제한 제거"
  echo "  --skip-test         — on 실행 후 실제 인증 테스트 생략"
  echo ""
  echo "예:"
  echo "  $0"
  echo "  $0 status"
  echo "  $0 on --user \"$(id -un)\""
  echo "  $0 on --allow-any-host"
  echo "  $0 off"
}

case "$ACTION" in
  on|--on|enable)
    ACTION=on
    if [ "$#" -gt 0 ]; then
      shift
    fi
    ;;
  off|--off|disable)
    ACTION=off
    shift
    ;;
  status|--status)
    ACTION=status
    RUN_TEST=0
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
    --skip-test)
      RUN_TEST=0
      shift
      ;;
    --allow-any-host)
      ALLOW_ANY_HOST=1
      shift
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
  elif [ "$(id -u)" -ne 0 ]; then
    id -un
  else
    stat -f '%Su' /dev/console
  fi
}

get_remote_login() {
  local output
  output=$(run_as_root systemsetup -getremotelogin 2>/dev/null || true)
  case "$output" in
    *": On") printf '%s\n' "On" ;;
    *": Off") printf '%s\n' "Off" ;;
    *) printf '%s\n' "Unknown" ;;
  esac
}

service_is_loaded() {
  run_as_root launchctl print system/com.openssh.sshd >/dev/null 2>&1
}

port_is_listening() {
  if command -v nc >/dev/null 2>&1; then
    nc -z -G 2 127.0.0.1 22 >/dev/null 2>&1
  else
    run_as_root lsof -nP -iTCP:22 -sTCP:LISTEN 2>/dev/null | grep -q LISTEN
  fi
}

group_exists() {
  dscl . -read "/Groups/$1" >/dev/null 2>&1
}

user_is_group_member() {
  dseditgroup -o checkmember -m "$1" "$2" 2>/dev/null | grep -q "yes"
}

target_has_any_host_access() {
  run_as_root sshd -T 2>/dev/null | awk -v user="$TARGET_USER" '
    $1 == "allowusers" && $2 == user { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

ensure_any_host_access() {
  local candidate backup_file

  if target_has_any_host_access; then
    echo "  - SSH 원본 호스트 제한 없음: $TARGET_USER"
    return
  fi

  candidate=$(mktemp "${TMPDIR:-/tmp}/hanlim-sshd-access.XXXXXX")
  backup_file="${SSHD_BACKUP_DIR}/99-mac-sshd-allowlist.before-any-host.conf"

  {
    echo "# Managed by hanlim-mac/0210_ssh-remote-login.sh"
    echo "# Allow the selected macOS account from LAN, VPN, or any other source."
    echo "PermitRootLogin no"
    echo "AllowUsers $TARGET_USER"
  } > "$candidate"
  chmod 600 "$candidate"

  run_as_root mkdir -p "$SSHD_BACKUP_DIR"
  run_as_root chmod 700 "$SSHD_BACKUP_DIR"
  if [ -f "$SSHD_ACCESS_CONFIG" ] && [ ! -f "$backup_file" ]; then
    run_as_root cp -p "$SSHD_ACCESS_CONFIG" "$backup_file"
    run_as_root chmod 600 "$backup_file"
    echo "  - 기존 SSH 접근 규칙 백업: $backup_file"
  fi

  run_as_root install -o root -g wheel -m 644 "$candidate" "$SSHD_ACCESS_CONFIG"
  rm -f "$candidate"

  if ! run_as_root sshd -t >/dev/null 2>&1; then
    echo "오류: 변경된 sshd 설정 문법 검사에 실패했습니다."
    if [ -f "$backup_file" ]; then
      run_as_root install -o root -g wheel -m 644 "$backup_file" "$SSHD_ACCESS_CONFIG"
      echo "  - 기존 SSH 접근 규칙을 복구했습니다."
    fi
    return 1
  fi

  if ! target_has_any_host_access; then
    echo "오류: $TARGET_USER 계정의 원본 호스트 제한을 제거하지 못했습니다."
    return 1
  fi

  echo "  - SSH 원본 호스트 제한 제거 완료: AllowUsers $TARGET_USER"
}

ensure_target_user_access() {
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "오류: 로컬 계정을 찾을 수 없습니다: $TARGET_USER"
    return 1
  fi

  # com.apple.access_ssh가 없으면 macOS의 '모든 사용자' 모드다.
  # 이미 제한 모드라면 기존 허용 사용자는 유지하고 대상 사용자만 추가한다.
  if group_exists com.apple.access_ssh; then
    if user_is_group_member "$TARGET_USER" com.apple.access_ssh; then
      echo "  - SSH 사용자 ACL 허용 확인: $TARGET_USER"
    else
      echo "  - 제한된 SSH 사용자 ACL에 추가: $TARGET_USER"
      run_as_root dseditgroup -o edit -a "$TARGET_USER" -t user com.apple.access_ssh
    fi
  else
    echo "  - SSH 사용자 ACL: 모든 로컬 사용자 허용"
  fi
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

print_status() {
  local remote_login acl_status status_ok
  remote_login=$(get_remote_login)
  status_ok=1

  echo "==> SSH 원격 로그인 상태"
  echo "  - macOS Remote Login: $remote_login"
  [ "$remote_login" = "On" ] || status_ok=0

  if service_is_loaded; then
    echo "  - launchd com.openssh.sshd: 로드됨"
  else
    echo "  - launchd com.openssh.sshd: 로드되지 않음"
    status_ok=0
  fi

  if port_is_listening; then
    echo "  - TCP 22: LISTEN"
  else
    echo "  - TCP 22: 닫힘"
    status_ok=0
  fi

  if group_exists com.apple.access_ssh; then
    if user_is_group_member "$TARGET_USER" com.apple.access_ssh; then
      acl_status="허용"
    else
      acl_status="차단"
      status_ok=0
    fi
    echo "  - 사용자 ACL: $TARGET_USER $acl_status (선택한 사용자만 허용)"
  else
    echo "  - 사용자 ACL: $TARGET_USER 허용 (모든 로컬 사용자 허용)"
  fi

  if target_has_any_host_access; then
    echo "  - 원본 호스트 제한: 없음"
  else
    echo "  - 원본 호스트 제한: 있음"
  fi

  if run_as_root sshd -t >/dev/null 2>&1; then
    echo "  - sshd 설정 문법: 정상"
  else
    echo "  - sshd 설정 문법: 오류"
    status_ok=0
  fi

  [ "$status_ok" -eq 1 ]
}

print_connection_info() {
  local local_host lan_ip tailscale_ip
  local_host=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
  lan_ip=$(get_lan_ip)
  tailscale_ip=$(get_tailscale_ip)

  echo ""
  echo "────────────────────────────────────────────────────────"
  echo " SSH 접속 정보"
  echo "────────────────────────────────────────────────────────"
  echo "  계정          : $TARGET_USER"
  echo "  Bonjour 호스트: ${local_host}.local"
  [ -n "$lan_ip" ] && echo "  LAN IP        : $lan_ip"
  [ -n "$tailscale_ip" ] && echo "  Tailscale 후보: $tailscale_ip"
  echo ""
  echo "  같은 LAN: ssh ${TARGET_USER}@${local_host}.local"
  [ -n "$lan_ip" ] && echo "  LAN IP  : ssh ${TARGET_USER}@${lan_ip}"
  [ -n "$tailscale_ip" ] && echo "  Tailscale 후보: ssh ${TARGET_USER}@${tailscale_ip}"
  echo ""
  echo "  비밀번호 인증 시 이 Mac의 macOS 로그인 비밀번호를 사용합니다."
  if ! target_has_any_host_access; then
    echo "  주의: sshd AllowUsers 원본 IP 제한이 있어 주소별 허용 여부가 다를 수 있습니다."
    echo "  주소 검사: ${TEST_SCRIPT} --host 접속주소"
  fi
  echo "  외부 인터넷에 TCP 22를 직접 포트 포워딩하지 말고 VPN을 사용하세요."
  echo "────────────────────────────────────────────────────────"
}

TARGET_USER="${TARGET_USER:-$(get_default_user)}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "오류: 로컬 계정을 찾을 수 없습니다: $TARGET_USER"
  exit 1
fi

if [ "$ACTION" = "status" ]; then
  print_status
  exit $?
fi

# sudo 인증을 시작할 때 한 번만 요청한다.
run_as_root true

if [ "$ACTION" = "off" ]; then
  echo "==> SSH 원격 로그인 끄기"
  if [ "$(get_remote_login)" = "Off" ] && ! port_is_listening; then
    echo "  - 이미 꺼져 있습니다."
  else
    set +e
    disable_output=$(run_as_root systemsetup -setremotelogin -f off 2>&1)
    disable_result=$?
    set -e
    [ -n "$disable_output" ] && echo "$disable_output" | sed 's/^/  /'

    if [ "$disable_result" -ne 0 ] || port_is_listening; then
      echo "  - launchd sshd 소켓도 비활성화합니다."
      run_as_root launchctl disable system/com.openssh.sshd 2>/dev/null || true
      run_as_root launchctl bootout system/com.openssh.sshd 2>/dev/null || true
    fi
  fi

  echo ""
  if [ "$(get_remote_login)" = "Off" ] && ! port_is_listening; then
    echo "완료: SSH 원격 로그인이 꺼졌고 TCP 22도 닫혔습니다."
    exit 0
  fi

  echo "오류: SSH 원격 로그인을 완전히 끄지 못했습니다."
  echo "시스템 설정 > 일반 > 공유 > 원격 로그인에서 상태를 확인하세요."
  exit 1
fi

echo "==> SSH 원격 로그인 켜기"
if [ "$(get_remote_login)" = "On" ]; then
  echo "  - Remote Login이 이미 켜져 있습니다."
else
  set +e
  enable_output=$(run_as_root systemsetup -setremotelogin on 2>&1)
  enable_result=$?
  set -e
  [ -n "$enable_output" ] && echo "$enable_output" | sed 's/^/  /'

  if [ "$enable_result" -ne 0 ]; then
    echo "  - systemsetup 실패 후 launchd 활성화를 시도합니다."
  fi
fi

run_as_root launchctl enable system/com.openssh.sshd 2>/dev/null || true
if ! service_is_loaded; then
  run_as_root launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist \
    2>/dev/null || true
fi

if [ "$ALLOW_ANY_HOST" -eq 1 ]; then
  ensure_any_host_access
fi

ensure_target_user_access

echo ""
if ! print_status; then
  echo ""
  echo "오류: Remote Login 또는 TCP 22 확인에 실패했습니다."
  echo "systemsetup에는 실행 중인 터미널의 전체 디스크 접근 권한이 필요할 수 있습니다."
  echo "시스템 설정 > 개인정보 보호 및 보안 > 전체 디스크 접근 권한을 확인하세요."
  exit 1
fi

print_connection_info

if [ "$RUN_TEST" -eq 1 ]; then
  if [ ! -x "$TEST_SCRIPT" ]; then
    echo ""
    echo "오류: 테스트 스크립트를 실행할 수 없습니다: $TEST_SCRIPT"
    exit 1
  fi

  echo ""
  "$TEST_SCRIPT" --user "$TARGET_USER"
fi

echo ""
echo "완료: SSH 원격 로그인이 켜졌습니다."
