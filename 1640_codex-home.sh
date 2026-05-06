#!/bin/bash
set -euo pipefail

echo "==> Codex 설정 디렉터리 리디렉트"
echo "   CODEX_HOME=/Volumes/ubuntu/.codex (Samba 공유)"
echo ""

LABEL="com.openai.codex.CODEX_HOME"
TARGET_DIR="/Volumes/ubuntu/.codex"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

fail() {
  echo "오류: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 명령을 찾을 수 없습니다."
}

verify_state() {
  local actual
  local plist_label
  local plist_program
  local plist_action
  local plist_name
  local plist_value

  echo ""
  echo "==> 적용 상태 검증"

  [ -f "$PLIST" ] || fail "plist 가 생성되지 않았습니다: $PLIST"
  plutil -lint "$PLIST" >/dev/null || fail "plist 문법 검증 실패: $PLIST"
  echo "--- plist 문법 OK"

  plist_label=$(/usr/libexec/PlistBuddy -c "Print :Label" "$PLIST")
  [ "$plist_label" = "$LABEL" ] || fail "plist Label 불일치: $plist_label"

  plist_program=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$PLIST")
  plist_action=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:1" "$PLIST")
  plist_name=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:2" "$PLIST")
  plist_value=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:3" "$PLIST")
  [ "$plist_program" = "/bin/launchctl" ] || fail "plist ProgramArguments[0] 불일치: $plist_program"
  [ "$plist_action" = "setenv" ] || fail "plist ProgramArguments[1] 불일치: $plist_action"
  [ "$plist_name" = "CODEX_HOME" ] || fail "plist ProgramArguments[2] 불일치: $plist_name"
  [ "$plist_value" = "$TARGET_DIR" ] || fail "plist ProgramArguments[3] 불일치: $plist_value"
  echo "--- plist 내용 OK"

  launchctl print "${GUI_DOMAIN}/${LABEL}" >/dev/null || fail "LaunchAgent 가 로드되지 않았습니다: ${GUI_DOMAIN}/${LABEL}"
  echo "--- LaunchAgent 로드 OK"

  actual=$(launchctl getenv CODEX_HOME 2>/dev/null || true)
  [ "$actual" = "$TARGET_DIR" ] || fail "CODEX_HOME 값 불일치: ${actual:-<unset>}"
  echo "--- CODEX_HOME 값 OK: $actual"
}

require_command launchctl
require_command plutil
require_command /usr/libexec/PlistBuddy

# ── 1. 대상 디렉터리 존재 확인 (Samba 마운트 필요) ─────────────
if [ ! -d "$TARGET_DIR" ]; then
  echo "경고: $TARGET_DIR 가 없습니다."
  echo "      Samba 가 마운트되지 않았을 수 있습니다. (1340_home-samba-link.sh 먼저 실행)"
  echo "      그래도 plist 는 등록합니다 — 다음 로그인부터 적용됩니다."
  echo ""
fi

# ── 2. LaunchAgent plist 생성 ─────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/launchctl</string>
        <string>setenv</string>
        <string>CODEX_HOME</string>
        <string>${TARGET_DIR}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST_EOF

echo "--- plist 생성: $PLIST"

# ── 3. 기존 LaunchAgent unload 후 재로드 ──────────────────────
launchctl bootout "${GUI_DOMAIN}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST"
echo "--- LaunchAgent 등록 완료 (다음 로그인부터 자동 적용)"

# ── 4. 현재 세션에도 즉시 적용 ────────────────────────────────
launchctl setenv CODEX_HOME "$TARGET_DIR"
echo "--- 현재 세션에 환경 변수 즉시 적용"

verify_state

echo ""
echo "완료: CODEX_HOME = $(launchctl getenv CODEX_HOME)"
echo ""
echo "※ 이후 codex 실행 시 ~/.codex 가 아닌 $TARGET_DIR 를 사용합니다."
echo "※ 해제하려면:"
echo "   launchctl bootout ${GUI_DOMAIN}/${LABEL}"
echo "   rm $PLIST"
