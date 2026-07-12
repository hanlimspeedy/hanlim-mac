#!/bin/bash
set -e

echo "==> Karabiner-Elements 설치 + Shift+Space 한영전환 + Ctrl↔Cmd 스왑"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

KARABINER_CONFIG_DIR="$HOME/.config/karabiner"
KARABINER_CONFIG="$KARABINER_CONFIG_DIR/karabiner.json"
KARABINER_STATE="/Library/Application Support/org.pqrs/tmp/karabiner_core_service_state.json"
KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
JQ="$(command -v jq || true)"
EXTERNAL_KEYBOARD_VENDOR_DEC=9639
EXTERNAL_KEYBOARD_PRODUCT_DEC=64097
EXTERNAL_KEYBOARD_VENDOR_HEX=0x25a7
EXTERNAL_KEYBOARD_PRODUCT_HEX=0xfa61

# Karabiner-Elements 설치
if ! brew list --cask karabiner-elements &>/dev/null; then
  brew install --cask karabiner-elements
fi

# Karabiner 설정 복사
mkdir -p "$KARABINER_CONFIG_DIR"
cp "$(dirname "$0")/config/karabiner.json" "$KARABINER_CONFIG"

# 설정에 2.4G 외장 키보드 HID가 포함되어 있는지 검증한다.
if [ -z "$JQ" ]; then
  echo "오류: jq가 없어 Karabiner 설정을 검증할 수 없습니다." >&2
  exit 1
fi
if ! "$JQ" -e \
  --argjson vendor "$EXTERNAL_KEYBOARD_VENDOR_DEC" \
  --argjson product "$EXTERNAL_KEYBOARD_PRODUCT_DEC" \
  '.profiles[].devices[]? | select(.identifiers.vendor_id == $vendor and .identifiers.product_id == $product and .identifiers.is_keyboard == true)' \
  "$KARABINER_CONFIG" >/dev/null; then
  echo "오류: Karabiner 설정에 2.4G 외장 키보드 HID가 없습니다: vendor=$EXTERNAL_KEYBOARD_VENDOR_DEC product=$EXTERNAL_KEYBOARD_PRODUCT_DEC" >&2
  exit 1
fi

# Shift+Space는 Caps Lock으로 변환한다.
# select_input_source는 메뉴바만 바뀌고 실제 앱 입력이 영어로 남을 수 있다.
# macOS 입력 소스 순환 단축키도 입력 소스 목록에 따라 한 번에 전환되지 않을 수 있어 끈다.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>262144</integer></array></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>786432</integer></array></dict></dict>"
defaults write com.apple.HIToolbox AppleGlobalTextInputProperties -dict TextInputGlobalPropertyPerContextInput -bool false
defaults write com.apple.HIToolbox AppleCapsLockPressAndHoldToggleOff -bool true
killall cfprefsd 2>/dev/null || true
killall TextInputMenuAgent 2>/dev/null || true
killall keyboardservicesd 2>/dev/null || true

# Karabiner 설정 재로드. 실패해도 아래 진단에서 원인을 보여준다.
if [ -x "$KARABINER_CLI" ]; then
  "$KARABINER_CLI" --select-profile "Windows Style" >/dev/null 2>&1 || true
fi
if sudo -n true 2>/dev/null; then
  sudo launchctl kickstart -k system/org.pqrs.service.daemon.Karabiner-Core-Service >/dev/null 2>&1 || true
  sudo launchctl kickstart -k system/org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon >/dev/null 2>&1 || true
fi
launchctl kickstart -k "gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server" >/dev/null 2>&1 || true
sleep 3

echo ""
echo "완료: Karabiner-Elements 설정 적용"
echo "  - 2.4G 외장 키보드($EXTERNAL_KEYBOARD_VENDOR_HEX/$EXTERNAL_KEYBOARD_PRODUCT_HEX) Ctrl ↔ Cmd 스왑"
echo "  - Shift+Space → Caps Lock → macOS 네이티브 한영전환"
echo "  - Caps Lock 길게 누르기 대문자 고정 끔"
echo ""
echo "진단:"
if command -v hidutil >/dev/null 2>&1; then
  if hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}' 2>/dev/null | grep -qi "2.4G Receiver"; then
    echo "  - 2.4G Receiver 키보드 감지됨"
  else
    echo "  - 주의: 현재 2.4G Receiver 키보드가 감지되지 않음"
  fi
fi
if [ -f "$KARABINER_STATE" ]; then
  hid_device_open_permitted="$("$JQ" -r 'if has("hid_device_open_permitted") then .hid_device_open_permitted else empty end' "$KARABINER_STATE" 2>/dev/null)"
  if [ -n "$hid_device_open_permitted" ]; then
    echo "  - hid_device_open_permitted=$hid_device_open_permitted"
  fi
  if [ "$hid_device_open_permitted" = "false" ]; then
    echo "  - 오류: Karabiner-Core-Service가 입력 장치를 열 권한이 없음"
    echo "    시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링에서 Karabiner-Core-Service 허용 필요"
    pkill -x Karabiner-EventViewer 2>/dev/null || true
    open -n -a "Karabiner-Elements" --args input-monitoring-macos26 >/dev/null 2>&1 || true
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" >/dev/null 2>&1 || true
  fi
fi
if [ -x "$KARABINER_CLI" ]; then
  cli_devices_output="$("$KARABINER_CLI" --list-connected-devices 2>&1 || true)"
  if printf "%s\n" "$cli_devices_output" | grep -q "error:"; then
    echo "  - 오류: karabiner_cli가 Core Service에 연결하지 못함"
    echo "    Karabiner 권한 허용 후 앱 또는 재로그인이 필요할 수 있음"
  fi
fi
echo ""
echo "※ 최초 설치 시 Karabiner-Elements 실행 후 아래 권한 허용 필요:"
echo "  1. 입력 모니터링: Karabiner-Core-Service"
echo "  2. 로그인 항목: Karabiner 백그라운드 항목 ON"
echo "  3. 드라이버 확장 프로그램: Karabiner-VirtualHIDDevice-Manager ON"
echo "  ※ 권한 설정 후 재부팅 필요"
