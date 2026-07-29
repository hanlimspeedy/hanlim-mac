#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

TARGET_USER=""
OUTPUT_DIR=""
KEY_NAME="mac-air-m1_ed25519"

usage() {
  echo "사용법: $0 [--user macOS계정] [--output-dir 폴더] [--name 키이름]"
  echo ""
  echo "전용 Ed25519 SSH 키를 만들고 대상 계정의 authorized_keys에 공개키를"
  echo "중복 없이 등록합니다. 기존 개인키는 덮어쓰지 않습니다."
  echo ""
  echo "기본 출력: ~/Desktop/mac-air-m1/mac-air-m1_ed25519"
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
    --output-dir)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --output-dir 뒤에 폴더를 입력하세요."
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --name)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "오류: --name 뒤에 키 파일 이름을 입력하세요."
        exit 1
      fi
      KEY_NAME="$2"
      shift 2
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
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

TARGET_USER="${TARGET_USER:-$(id -un)}"
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "오류: 로컬 계정을 찾을 수 없습니다: $TARGET_USER"
  exit 1
fi

if [ "$(id -u)" -ne "$(id -u "$TARGET_USER")" ]; then
  echo "오류: 키 등록 대상 계정으로 sudo 없이 실행하세요: $TARGET_USER"
  exit 1
fi

target_home=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null \
  | awk '{print $2; exit}')
if [ -z "$target_home" ] || [ ! -d "$target_home" ]; then
  echo "오류: 대상 계정의 홈 디렉터리를 찾을 수 없습니다."
  exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-${target_home}/Desktop/mac-air-m1}"
PRIVATE_KEY="${OUTPUT_DIR}/${KEY_NAME}"
PUBLIC_KEY="${PRIVATE_KEY}.pub"
SSH_DIR="${target_home}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

case "$KEY_NAME" in
  ""|"."|".."|*/*)
    echo "오류: --name에는 경로 구분자 없이 파일 이름만 입력하세요."
    exit 1
    ;;
esac

if [ -L "$OUTPUT_DIR" ] || [ -L "$SSH_DIR" ] || [ -L "$AUTHORIZED_KEYS" ]; then
  echo "오류: 안전을 위해 키 경로와 .ssh 경로의 심볼릭 링크는 사용하지 않습니다."
  exit 1
fi

umask 077
mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"

if [ -f "$PRIVATE_KEY" ]; then
  if [ ! -f "$PUBLIC_KEY" ]; then
    ssh-keygen -y -f "$PRIVATE_KEY" > "$PUBLIC_KEY"
  fi
  echo "==> 기존 개인키 사용: $PRIVATE_KEY"
else
  if [ -e "$PUBLIC_KEY" ]; then
    echo "오류: 공개키만 이미 존재합니다. 개인키를 덮어쓰지 않습니다: $PUBLIC_KEY"
    exit 1
  fi

  echo "==> Ed25519 접속 키 생성"
  ssh-keygen -q -t ed25519 -a 100 -N "" \
    -C "${TARGET_USER}@mac-air-m1-tailscale" -f "$PRIVATE_KEY"
fi

chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

derived_key=$(ssh-keygen -y -f "$PRIVATE_KEY")
public_type=$(awk '{print $1}' "$PUBLIC_KEY")
public_blob=$(awk '{print $2}' "$PUBLIC_KEY")
derived_type=$(printf '%s\n' "$derived_key" | awk '{print $1}')
derived_blob=$(printf '%s\n' "$derived_key" | awk '{print $2}')

if [ "$public_type" != "$derived_type" ] || [ "$public_blob" != "$derived_blob" ]; then
  echo "오류: 개인키와 공개키가 서로 일치하지 않습니다."
  exit 1
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

if awk -v key_type="$public_type" -v key_blob="$public_blob" '
  $1 == key_type && $2 == key_blob { found = 1 }
  END { exit(found ? 0 : 1) }
' "$AUTHORIZED_KEYS"; then
  echo "==> 공개키가 authorized_keys에 이미 등록되어 있습니다."
else
  if [ -s "$AUTHORIZED_KEYS" ] \
    && [ "$(tail -c 1 "$AUTHORIZED_KEYS" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$AUTHORIZED_KEYS"
  fi
  printf '%s\n' "$(<"$PUBLIC_KEY")" >> "$AUTHORIZED_KEYS"
  echo "==> 공개키를 authorized_keys에 등록했습니다."
fi

echo ""
echo "완료:"
echo "  개인키: $PRIVATE_KEY"
echo "  공개키: $PUBLIC_KEY"
echo "  등록:   $AUTHORIZED_KEYS"
