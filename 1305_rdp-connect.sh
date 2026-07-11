#!/bin/bash
set -e

echo "==> Windows RDP 자동 연결"

# 환경변수에서 접속 정보 읽기
# .env 파일 또는 환경변수로 설정:
#   export SMB_HOST=100.127.167.63
#   export RDP_USER=trainisshopping@outlook.com
#   export RDP_PASS=비밀번호
# 선택:
#   export RDP_HOST=100.127.167.63
#   export RDP_PORT=3389
if [ -f "$(dirname "$0")/.env" ]; then
  source "$(dirname "$0")/.env"
fi

RDP_HOST="${RDP_HOST:-$SMB_HOST}"
RDP_USER="${RDP_USER:-$SMB_USER}"
RDP_PORT="${RDP_PORT:-3389}"
FORCE_OPEN=0
RUN_FREERDP=0

if [ "${1:-}" = "--force" ]; then
  FORCE_OPEN=1
elif [ "${1:-}" = "--run-freerdp" ]; then
  RUN_FREERDP=1
fi

if [ -z "$RDP_HOST" ] || [ -z "$RDP_USER" ] || [ -z "${RDP_PASS:-}" ]; then
  echo "오류: RDP 접속 정보가 부족합니다."
  echo ""
  echo "설정 방법: mac-setup/.env 파일 생성"
  echo '  SMB_HOST=100.127.167.63'
  echo '  RDP_USER=trainisshopping@outlook.com'
  echo '  RDP_PASS=비밀번호'
  echo ""
  echo "선택:"
  echo '  RDP_HOST=100.127.167.63'
  echo '  RDP_PORT=3389'
  exit 1
fi

# Homebrew 환경 로드
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v sdl-freerdp >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "오류: FreeRDP 설치에 Homebrew가 필요합니다. 0300_homebrew.sh 먼저 실행하세요."
    exit 1
  fi

  echo "  - FreeRDP 설치 중..."
  brew install freerdp
else
  echo "  - FreeRDP 이미 설치됨"
fi

if command -v nc >/dev/null 2>&1; then
  if nc -vz -G 3 "$RDP_HOST" "$RDP_PORT" >/dev/null 2>&1; then
    echo "  - RDP 포트 열림: ${RDP_HOST}:${RDP_PORT}"
  elif [ "$FORCE_OPEN" = "1" ]; then
    echo "  ! 경고: ${RDP_HOST}:${RDP_PORT} 접속 확인 실패. 그래도 FreeRDP를 엽니다."
  else
    echo "오류: ${RDP_HOST}:${RDP_PORT} 에 연결할 수 없습니다."
    echo "  - 서버는 켜져 있어도 Windows 원격 데스크톱이 꺼져 있거나 방화벽에서 3389가 막혔을 수 있습니다."
    echo "  - 확인 후 다시 실행하세요. 포트 확인을 건너뛰려면: $0 --force"
    exit 2
  fi
fi

RDP_ADDRESS="${RDP_HOST}:${RDP_PORT}"
RDP_LOGIN_USER="$RDP_USER"
if [[ "$RDP_LOGIN_USER" == *@* && "$RDP_LOGIN_USER" != *\\* ]]; then
  RDP_LOGIN_USER="MicrosoftAccount\\${RDP_LOGIN_USER}"
fi

LOG_FILE="${TMPDIR:-/tmp}/hanlim-sdl-freerdp.log"

if [ "$RUN_FREERDP" = "1" ]; then
  exec sdl-freerdp \
    /v:"$RDP_ADDRESS" \
    /u:"$RDP_LOGIN_USER" \
    /p:"$RDP_PASS" \
    /cert:ignore \
    /dynamic-resolution
fi

RUNNER="${TMPDIR:-/tmp}/hanlim-rdp.command"
cat >"$RUNNER" <<EOF
#!/bin/bash
cd "$(pwd)"
exec ./1305_rdp-connect.sh --run-freerdp 2>&1 | tee "$LOG_FILE"
EOF
chmod +x "$RUNNER"
open -a Terminal "$RUNNER"

echo ""
echo "완료: Terminal에서 RDP 자동 연결을 시작했습니다 (계정: ${RDP_LOGIN_USER})"
echo "  - log: $LOG_FILE"
