#!/bin/bash
set -euo pipefail

LC_ALL=C
export LC_ALL

APP_PATH="/Applications/RustDesk.app"
CASK_NAME="rustdesk"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

if command -v brew >/dev/null 2>&1; then
  BREW_BIN=$(command -v brew)
elif [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
else
  echo "오류: Homebrew를 찾을 수 없습니다."
  echo "먼저 ./0300_homebrew.sh 를 실행하세요."
  exit 1
fi

echo "==> RustDesk 설치"

if "$BREW_BIN" list --cask "$CASK_NAME" >/dev/null 2>&1; then
  if [ -d "$APP_PATH" ]; then
    echo "RustDesk 이미 설치됨"
  else
    echo "Homebrew 등록은 있으나 앱이 없어 재설치합니다."
    "$BREW_BIN" reinstall --cask "$CASK_NAME"
  fi
elif [ -d "$APP_PATH" ]; then
  echo "RustDesk 앱이 이미 설치되어 있어 기존 앱을 사용합니다."
else
  "$BREW_BIN" install --cask "$CASK_NAME"
fi

if [ ! -x "$APP_PATH/Contents/MacOS/RustDesk" ]; then
  echo "오류: RustDesk 실행 파일을 찾을 수 없습니다."
  exit 2
fi

RUSTDESK_VERSION=$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "확인 안 됨"
)

open -a RustDesk

echo ""
echo "완료: RustDesk ${RUSTDESK_VERSION} 설치 및 실행됨"
echo "  앱 위치: $APP_PATH"
echo ""
echo "다음 단계:"
echo "  ./1365_rustdesk-autostart.sh on"
echo ""
echo "최초 한 번 macOS 권한을 허용하세요:"
echo "  - 시스템 설정 → 개인정보 보호 및 보안 → 화면 및 시스템 오디오 녹음"
echo "  - 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용"
echo "  - 키보드/마우스 제어가 안 되면 입력 모니터링도 허용"
