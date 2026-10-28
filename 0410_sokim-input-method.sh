#!/bin/bash
set -euo pipefail

# 속 입력기(SokIM): 한글/영문 엔진을 한 입력기 안에 두고 한영전환을 내부 상태로 처리한다.
# macOS 입력 소스 전환(ABC↔두벌식)을 쓰지 않아 전환 지연, 첫 글자 씹힘,
# "메뉴바만 한글이고 입력은 영어" 문제가 생기지 않는다.
# 상세 문서: config/SOKIM.md

SOKIM_CASK="sokim"
SOKIM_APP="/Library/Input Methods/SokIM.app"
SOKIM_BUNDLE_ID="com.kiding.inputmethod.sok"
SOKIM_MODE_ID="com.kiding.inputmethod.sok.mode"
APPLE_KOREAN_ID="com.apple.inputmethod.Korean"
APPLE_2SET_ID="com.apple.inputmethod.Korean.2SetKorean"
# 속 입력기는 샌드박스 앱이라 설정이 컨테이너에 있다. 컨테이너는 첫 실행 때 생긴다.
SOKIM_PREFS="$HOME/Library/Containers/$SOKIM_BUNDLE_ID/Data/Library/Preferences/$SOKIM_BUNDLE_ID"
# 속 입력기 한/A 전환키. Caps Lock은 윈도우처럼 대문자 고정으로만 쓴다.
ROTATE_SHORTCUTS=(ShiftSpace)
KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
ACTION="${1:-install}"

usage() {
  echo "사용법: $0 [install|status|uninstall]"
  echo ""
  echo "  install    (기본) — 속 입력기 설치, 입력 소스를 속 입력기로 교체, Shift+Space 한영키 설정"
  echo "  status            — 설치, 입력 소스, 한영키 설정 상태 확인"
  echo "  uninstall         — macOS 두벌식으로 되돌리고 속 입력기 제거"
}

case "$ACTION" in
  install|--install)
    ACTION=install
    ;;
  status|--status)
    ACTION=status
    ;;
  uninstall|--uninstall|rollback)
    ACTION=uninstall
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

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# TIS(Text Input Sources) API 호출. 인자는 "동작 [입력소스ID|앱경로]"의 나열이다.
#   list | register <앱 경로> | enable <ID> | disable <ID> | select <ID>
# 이미 원하는 상태인 enable/disable은 건너뛰어 반복 실행해도 안전하다.
tis() {
  # 입력기 설치 직후 TIS가 남기는 키보드 레이아웃 캐시 경고는 숨긴다.
  swift - "$@" 2> >(grep -v -e 'Keyboard Layouts:' -e 'TISFileInterrogator' >&2) <<'SWIFT'
import Carbon
import Foundation

func inputSources(_ id: String?, includeAllInstalled: Bool) -> [TISInputSource] {
    var filter: [String: Any] = [:]
    if let id { filter[kTISPropertyInputSourceID as String] = id }
    return TISCreateInputSourceList(filter as CFDictionary, includeAllInstalled)?
        .takeRetainedValue() as? [TISInputSource] ?? []
}

func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
}

var args = Array(CommandLine.arguments.dropFirst())
var failed = false

func fail(_ message: String) {
    print("오류: \(message)")
    failed = true
}

while !args.isEmpty {
    let op = args.removeFirst()
    if op == "list" {
        for source in inputSources(nil, includeAllInstalled: false) {
            let category: String = property(source, kTISPropertyInputSourceCategory) ?? ""
            guard category == kTISCategoryKeyboardInputSource as String else { continue }
            let id: String = property(source, kTISPropertyInputSourceID) ?? "?"
            let selected: Bool = property(source, kTISPropertyInputSourceIsSelected) ?? false
            print(selected ? "  * \(id)" : "    \(id)")
        }
        continue
    }
    guard !args.isEmpty else {
        fail("\(op) 뒤에 대상이 없습니다")
        break
    }
    let target = args.removeFirst()
    if op == "register" {
        let status = TISRegisterInputSource(URL(fileURLWithPath: target) as CFURL)
        if status != noErr { fail("register \(target) (\(status))") }
        continue
    }
    guard let source = inputSources(target, includeAllInstalled: true).first else {
        fail("입력 소스를 찾을 수 없습니다: \(target)")
        continue
    }
    let enabled: Bool = property(source, kTISPropertyInputSourceIsEnabled) ?? false
    var status: OSStatus = noErr
    switch op {
    case "enable":
        if !enabled { status = TISEnableInputSource(source) }
    case "disable":
        if enabled { status = TISDisableInputSource(source) }
    case "select":
        status = TISSelectInputSource(source)
    default:
        fail("알 수 없는 동작: \(op)")
        continue
    }
    if status != noErr { fail("\(op) \(target) (\(status))") }
}
exit(failed ? 1 : 0)
SWIFT
}

karabiner_maps_shift_space() {
  [ -f "$KARABINER_CONFIG" ] && command -v jq >/dev/null 2>&1 && jq -e \
    '[.profiles[].complex_modifications.rules[].manipulators[] | select(.from.key_code == "spacebar" and ((.from.modifiers.mandatory // []) | any(test("shift"))))] | length > 0' \
    "$KARABINER_CONFIG" >/dev/null 2>&1
}

print_status() {
  echo "상태:"
  local version
  version="$(brew list --cask --versions "$SOKIM_CASK" 2>/dev/null || true)"
  if [ -n "$version" ] && [ -d "$SOKIM_APP" ]; then
    echo "  - 설치됨: $version"
  else
    echo "  - 속 입력기 설치 안 됨"
  fi
  if pgrep -x SokIM >/dev/null 2>&1; then
    echo "  - SokIM 프로세스 실행 중"
  else
    echo "  - SokIM 프로세스 없음 (속 입력기를 선택하면 실행됨)"
  fi
  echo "  - 활성 입력 소스 (* 현재 선택):"
  tis list || true
  echo "  - 한/A 전환키: $(defaults read "$SOKIM_PREFS" RotateShortcuts 2>/dev/null | tr -d '\n ' || echo '기본값(CapsLock)')"
  if karabiner_maps_shift_space; then
    echo "  - 오류: Karabiner가 Shift+Space를 가로챔. ./0400_karabiner-windows-keys.sh 를 다시 실행"
  else
    echo "  - Karabiner Shift+Space 매핑 없음 (정상)"
  fi
}

if [ "$ACTION" = "status" ]; then
  print_status
  exit 0
fi

if [ "$ACTION" = "uninstall" ]; then
  echo "==> 속 입력기 제거 + macOS 두벌식 복귀"
  tis enable "$APPLE_KOREAN_ID" enable "$APPLE_2SET_ID" select "$APPLE_2SET_ID"
  if [ -d "$SOKIM_APP" ]; then
    tis disable "$SOKIM_MODE_ID" disable "$SOKIM_BUNDLE_ID" || true
  fi
  killall SokIM 2>/dev/null || true
  if brew list --cask "$SOKIM_CASK" &>/dev/null; then
    brew uninstall --cask "$SOKIM_CASK"
  fi
  echo ""
  echo "완료: 입력 소스를 macOS 두벌식으로 되돌림"
  echo "※ Shift+Space를 예전 Karabiner 방식으로 쓰려면 config/SOKIM.md의 '롤백' 참고"
  echo "※ 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링/손쉬운 사용의 \"속 입력기\" 항목은 직접 삭제"
  exit 0
fi

echo "==> 속 입력기(SokIM) 설치 + Shift+Space 한영전환"

if karabiner_maps_shift_space; then
  echo "오류: Karabiner가 Shift+Space를 다른 키로 바꾸고 있습니다. 먼저 ./0400_karabiner-windows-keys.sh 를 실행하세요." >&2
  exit 1
fi

if ! brew list --cask "$SOKIM_CASK" &>/dev/null; then
  brew install --cask "$SOKIM_CASK"
fi
if [ ! -d "$SOKIM_APP" ]; then
  echo "오류: 설치 후에도 $SOKIM_APP 이 없습니다." >&2
  exit 1
fi

# 입력 소스: 속 입력기만 쓰고 macOS 두벌식은 끈다.
# 두벌식이 켜져 있으면 macOS의 Caps Lock 전환이 두벌식으로 빠져나가 속 입력기와 충돌한다.
# ABC는 암호 입력 등 macOS 기본 동작용으로 남긴다.
# macOS 12부터 다른 회사 입력기는 프로그램이 켤 수 없고(TISEnableInputSource가 noErr를
# 돌려주지만 켜지지 않음) 사용자가 시스템 설정에서 직접 추가해야 한다. 추가 전에는 선택이
# 실패한다(TIS -50). 이때 두벌식을 끄면 한글 입력이 없어지므로, 선택에 성공한 경우에만 끈다.
tis register "$SOKIM_APP" enable "$SOKIM_BUNDLE_ID" enable "$SOKIM_MODE_ID" >/dev/null || true
if ! tis select "$SOKIM_MODE_ID" >/dev/null; then
  echo ""
  echo "설치됨: 속 입력기를 입력 소스에 직접 추가해야 합니다. 두벌식은 그대로 둡니다."
  echo "  1. 시스템 설정 → 키보드 → 텍스트 입력 → 입력 소스 \"편집...\""
  echo "  2. 왼쪽 아래 \"+\" → 영어 → \"속 입력기\" → \"추가\" (허용 확인 창이 뜨면 허용)"
  echo "  3. $0 를 다시 실행"
  echo "  ※ 목록에 속 입력기가 없으면 로그아웃 후 다시 로그인"
  open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" >/dev/null 2>&1 || true
  exit 0
fi
tis disable "$APPLE_2SET_ID" disable "$APPLE_KOREAN_ID"

# macOS 입력 소스 단축키(Ctrl+Space, Ctrl+Option+Space)는 끈다.
# 켜져 있으면 속 입력기에서 ABC로 빠져나가고, ABC에서는 Shift+Space가 동작하지 않는다.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>262144</integer></array></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>786432</integer></array></dict></dict>"
# 앱/문서별 입력 소스 자동 전환을 끈다. 켜져 있으면 창마다 ABC로 되돌아갈 수 있다.
defaults write com.apple.HIToolbox AppleGlobalTextInputProperties -dict TextInputGlobalPropertyPerContextInput -bool false
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# 한/A 전환키. 속 입력기가 선택되어 처음 실행되면 컨테이너가 생긴다.
# 실행 중인 속 입력기는 시작할 때만 설정을 읽으므로 기록 후 재시작한다(macOS가 다시 띄운다).
for _ in $(seq 1 20); do
  [ -d "$(dirname "$SOKIM_PREFS")" ] && break
  sleep 1
done
ROTATE_SET=false
if [ -d "$(dirname "$SOKIM_PREFS")" ] \
  && defaults write "$SOKIM_PREFS" RotateShortcuts -array "${ROTATE_SHORTCUTS[@]}"; then
  ROTATE_SET=true
  killall SokIM 2>/dev/null || true
  sleep 1
  open -g "$SOKIM_APP" >/dev/null 2>&1 || true
fi

echo ""
echo "완료: 속 입력기 설치 및 선택"
if [ "$ROTATE_SET" = true ]; then
  echo "  - 한영전환: Shift+Space (Caps Lock은 대문자 고정만)"
else
  echo "  - 주의: 한영키 자동 설정 실패. 메뉴바 속 입력기 메뉴 → 한/A 전환 → ⇧스페이스만 체크 (한/A (⇪) 해제)"
fi
echo "  - macOS 두벌식 입력 소스 끔, Ctrl+Space 입력 소스 단축키 끔"
echo ""
print_status
echo ""
echo "※ 최초 설치 시 아래 권한을 허용해야 입력이 동작함 (허용 전에는 입력이 안 될 수 있음):"
echo "  1. 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링: \"속 입력기\" 켬"
echo "  2. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용: \"속 입력기\" 켬"
echo "  3. 허용 후 killall SokIM (macOS가 속 입력기를 다시 띄움)"
echo "  ※ 입력이 안 되면 메뉴바 입력 메뉴에서 ABC 선택 또는 $0 uninstall"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" >/dev/null 2>&1 || true
