#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

TARGET_USER=""
SSH_HOST=""
SSH_PORT=22
CONNECT_TIMEOUT=5
AUTH_TEST=1
TEMP_DIR=""
SSH_DIR=""
AUTHORIZED_KEYS=""
CREATED_SSH_DIR=0
CREATED_AUTHORIZED_KEYS=0
ORIGINAL_SSH_MODE=""
ORIGINAL_KEYS_MODE=""
ORIGINAL_KEYS_SIZE=0
APPENDED_SIZE=0
KEY_MARKER=""

usage() {
  echo "사용법: $0 [--user macOS계정] [--host 주소] [--port 포트] [--no-auth]"
  echo ""
  echo "Remote Login, 사용자 ACL, launchd, TCP 포트, SSH 핸드셰이크를 검사합니다."
  echo "기본값은 임시 공개키를 authorized_keys에 넣어 실제 로그인과 명령 실행까지"
  echo "테스트하며, 테스트 키와 임시 파일은 성공/실패 여부와 관계없이 제거합니다."
  echo ""
  echo "  --user 계정   — 테스트할 로컬 macOS 계정 (기본: 현재 사용자)"
  echo "  --host 주소   — 접속 대상 (기본: 기본 인터페이스의 LAN IP)"
  echo "  --port 포트   — SSH 포트 (기본: 22)"
  echo "  --no-auth     — authorized_keys를 건드리지 않고 핸드셰이크까지만 검사"
}

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
    --host)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --host 뒤에 주소를 입력하세요."
        exit 1
      fi
      SSH_HOST="$2"
      shift 2
      ;;
    --port)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --port 뒤에 포트 번호를 입력하세요."
        exit 1
      fi
      SSH_PORT="$2"
      shift 2
      ;;
    --no-auth)
      AUTH_TEST=0
      shift
      ;;
    -h|--help|help)
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
  echo "오류: 이 테스트는 macOS SSH 서버용입니다."
  exit 1
fi

case "$SSH_PORT" in
  ''|*[!0-9]*)
    echo "오류: SSH 포트는 1~65535 사이 숫자여야 합니다."
    exit 1
    ;;
esac

if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  echo "오류: SSH 포트는 1~65535 사이 숫자여야 합니다."
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

get_lan_ip() {
  local default_interface
  default_interface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')

  if [ -n "$default_interface" ]; then
    ipconfig getifaddr "$default_interface" 2>/dev/null || true
  fi
}

group_exists() {
  dscl . -read "/Groups/$1" >/dev/null 2>&1
}

user_is_group_member() {
  dseditgroup -o checkmember -m "$1" "$2" 2>/dev/null | grep -q "yes"
}

restore_test_key() {
  local current_size expected_size cleanup_file

  if [ -n "$AUTHORIZED_KEYS" ] && [ -f "$AUTHORIZED_KEYS" ]; then
    if [ -n "$KEY_MARKER" ]; then
      current_size=$(stat -f '%z' "$AUTHORIZED_KEYS" 2>/dev/null || printf '%s' "-1")
      expected_size=$((ORIGINAL_KEYS_SIZE + APPENDED_SIZE))

      if [ "$current_size" -eq "$expected_size" ]; then
        truncate -s "$ORIGINAL_KEYS_SIZE" "$AUTHORIZED_KEYS" 2>/dev/null || true
      else
        # 테스트 중 다른 프로세스가 파일을 바꾼 경우 그 변경은 보존하고 테스트 키만 제거한다.
        cleanup_file="${TEMP_DIR}/authorized_keys.cleaned"
        awk -v marker="$KEY_MARKER" 'index($0, marker) == 0 { print }' \
          "$AUTHORIZED_KEYS" > "$cleanup_file" 2>/dev/null || true
        if [ -f "$cleanup_file" ]; then
          cp "$cleanup_file" "$AUTHORIZED_KEYS" 2>/dev/null || true
        fi
      fi
    fi

    if [ "$CREATED_AUTHORIZED_KEYS" -eq 1 ] && [ ! -s "$AUTHORIZED_KEYS" ]; then
      rm -f "$AUTHORIZED_KEYS"
    elif [ -n "$ORIGINAL_KEYS_MODE" ]; then
      chmod "$ORIGINAL_KEYS_MODE" "$AUTHORIZED_KEYS" 2>/dev/null || true
    fi
  fi

  if [ -n "$SSH_DIR" ] && [ -d "$SSH_DIR" ]; then
    if [ "$CREATED_SSH_DIR" -eq 1 ]; then
      rmdir "$SSH_DIR" 2>/dev/null || true
    elif [ -n "$ORIGINAL_SSH_MODE" ]; then
      chmod "$ORIGINAL_SSH_MODE" "$SSH_DIR" 2>/dev/null || true
    fi
  fi

  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap restore_test_key EXIT HUP INT TERM

TARGET_USER="${TARGET_USER:-$(get_default_user)}"
SSH_HOST="${SSH_HOST:-$(get_lan_ip)}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "오류: 로컬 계정을 찾을 수 없습니다: $TARGET_USER"
  exit 1
fi

echo "==> SSH 접속 허용 테스트"
echo "  - 대상: ${TARGET_USER}@${SSH_HOST}:${SSH_PORT}"

remote_login=$(run_as_root systemsetup -getremotelogin 2>/dev/null || true)
if echo "$remote_login" | grep -q ": On"; then
  echo "  [PASS] macOS Remote Login: On"
else
  echo "  [FAIL] macOS Remote Login이 켜져 있지 않습니다: ${remote_login:-확인 불가}"
  exit 1
fi

if group_exists com.apple.access_ssh; then
  if user_is_group_member "$TARGET_USER" com.apple.access_ssh; then
    echo "  [PASS] SSH 사용자 ACL: $TARGET_USER 허용"
  else
    echo "  [FAIL] SSH 사용자 ACL이 $TARGET_USER 계정을 허용하지 않습니다."
    exit 1
  fi
else
  echo "  [PASS] SSH 사용자 ACL: 모든 로컬 사용자 허용"
fi

if run_as_root launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
  echo "  [PASS] launchd com.openssh.sshd 로드됨"
else
  echo "  [FAIL] launchd com.openssh.sshd가 로드되지 않았습니다."
  exit 1
fi

if run_as_root sshd -t >/dev/null 2>&1; then
  echo "  [PASS] sshd 설정 문법 정상"
else
  echo "  [FAIL] sshd 설정 문법 오류"
  run_as_root sshd -t
  exit 1
fi

if nc -z -G "$CONNECT_TIMEOUT" "$SSH_HOST" "$SSH_PORT" >/dev/null 2>&1; then
  echo "  [PASS] TCP ${SSH_HOST}:${SSH_PORT} 연결 성공"
else
  echo "  [FAIL] TCP ${SSH_HOST}:${SSH_PORT}에 연결할 수 없습니다."
  exit 1
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hanlim-ssh-test.XXXXXX")
chmod 700 "$TEMP_DIR"

if ssh-keyscan -T "$CONNECT_TIMEOUT" -p "$SSH_PORT" "$SSH_HOST" \
  > "${TEMP_DIR}/known_hosts" 2>/dev/null \
  && [ -s "${TEMP_DIR}/known_hosts" ]; then
  echo "  [PASS] SSH 서버 호스트 키 수신"
else
  echo "  [FAIL] TCP 연결 후 SSH 핸드셰이크에 실패했습니다."
  exit 1
fi

if [ "$AUTH_TEST" -eq 0 ]; then
  echo ""
  echo "성공: SSH 서비스가 연결을 받고 핸드셰이크를 완료했습니다."
  echo "주의: --no-auth를 사용했으므로 사용자 인증은 검사하지 않았습니다."
  exit 0
fi

if [ "$(id -u)" -ne "$(id -u "$TARGET_USER")" ]; then
  echo "  [FAIL] 실제 인증 테스트는 대상 계정으로 직접 실행해야 합니다."
  echo "  다음 명령을 sudo 없이 실행하세요:"
  echo "    $0 --user \"$TARGET_USER\" --host \"$SSH_HOST\" --port \"$SSH_PORT\""
  exit 1
fi

target_home=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null \
  | awk '{print $2; exit}')
if [ -z "$target_home" ] || [ ! -d "$target_home" ]; then
  echo "  [FAIL] 대상 계정의 홈 디렉터리를 찾을 수 없습니다."
  exit 1
fi

SSH_DIR="${target_home}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

if [ -L "$SSH_DIR" ] || [ -L "$AUTHORIZED_KEYS" ]; then
  echo "  [FAIL] 안전을 위해 심볼릭 링크인 .ssh/authorized_keys는 수정하지 않습니다."
  exit 1
fi

if [ -e "$SSH_DIR" ] && [ ! -d "$SSH_DIR" ]; then
  echo "  [FAIL] ${SSH_DIR}가 디렉터리가 아닙니다."
  exit 1
fi

if [ -d "$SSH_DIR" ]; then
  ORIGINAL_SSH_MODE=$(stat -f '%Lp' "$SSH_DIR")
  chmod 700 "$SSH_DIR"
else
  mkdir "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  CREATED_SSH_DIR=1
fi

if [ -e "$AUTHORIZED_KEYS" ] && [ ! -f "$AUTHORIZED_KEYS" ]; then
  echo "  [FAIL] ${AUTHORIZED_KEYS}가 일반 파일이 아닙니다."
  exit 1
fi

if [ -f "$AUTHORIZED_KEYS" ]; then
  ORIGINAL_KEYS_MODE=$(stat -f '%Lp' "$AUTHORIZED_KEYS")
  ORIGINAL_KEYS_SIZE=$(stat -f '%z' "$AUTHORIZED_KEYS")
  chmod 600 "$AUTHORIZED_KEYS"
else
  : > "$AUTHORIZED_KEYS"
  chmod 600 "$AUTHORIZED_KEYS"
  CREATED_AUTHORIZED_KEYS=1
  ORIGINAL_KEYS_SIZE=0
fi

KEY_MARKER="hanlim-ssh-test-$$-$(date +%s)"
ssh-keygen -q -t ed25519 -N "" -C "$KEY_MARKER" -f "${TEMP_DIR}/test_key"
public_key=$(<"${TEMP_DIR}/test_key.pub")

append_prefix=""
if [ "$ORIGINAL_KEYS_SIZE" -gt 0 ] \
  && [ "$(tail -c 1 "$AUTHORIZED_KEYS" | wc -l | tr -d ' ')" -eq 0 ]; then
  append_prefix=$(printf '\n_')
  append_prefix=${append_prefix%_}
fi

printf '%s%s\n' "$append_prefix" "$public_key" >> "$AUTHORIZED_KEYS"
APPENDED_SIZE=$(( $(stat -f '%z' "$AUTHORIZED_KEYS") - ORIGINAL_KEYS_SIZE ))

auth_output=$(ssh \
  -i "${TEMP_DIR}/test_key" \
  -p "$SSH_PORT" \
  -o BatchMode=yes \
  -o ConnectTimeout="$CONNECT_TIMEOUT" \
  -o IdentitiesOnly=yes \
  -o KbdInteractiveAuthentication=no \
  -o PasswordAuthentication=no \
  -o PreferredAuthentications=publickey \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="${TEMP_DIR}/known_hosts" \
  -o LogLevel=ERROR \
  "${TARGET_USER}@${SSH_HOST}" \
  "printf HANLIM_SSH_AUTH_OK" 2>&1) || {
    echo "  [FAIL] SSH 공개키 인증 또는 원격 명령 실행 실패"
    [ -n "$auth_output" ] && echo "$auth_output" | sed 's/^/         /'
    if run_as_root sshd -T 2>/dev/null | grep -q '^allowusers '; then
      echo "         sshd AllowUsers의 사용자/원본 IP 제한도 확인하세요."
    fi
    exit 1
  }

if [ "$auth_output" = "HANLIM_SSH_AUTH_OK" ]; then
  echo "  [PASS] 임시 공개키 인증 및 원격 명령 실행 성공"
else
  echo "  [FAIL] 원격 명령의 응답이 예상과 다릅니다: $auth_output"
  exit 1
fi

echo ""
echo "성공: ${TARGET_USER}@${SSH_HOST}:${SSH_PORT} SSH 접속이 실제로 허용됩니다."
echo "테스트용 공개키는 종료 시 authorized_keys에서 자동 제거됩니다."
