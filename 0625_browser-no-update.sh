#!/bin/bash
set -e

echo "==> 브라우저 자동 업데이트 차단 (Chrome / Edge)"

# ── 현재 버전 확인 ──────────────────────────────────────────
CHROME_VER=$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version 2>/dev/null | sed 's/Google Chrome //' || echo "미설치")
EDGE_VER=$(/Applications/Microsoft\ Edge.app/Contents/MacOS/Microsoft\ Edge --version 2>/dev/null | sed 's/Microsoft Edge //' || echo "미설치")

echo ""
echo "현재 버전:"
echo "  Chrome : $CHROME_VER"
echo "  Edge   : $EDGE_VER"
echo ""

# ── 1. Google Chrome 자동 업데이트 차단 ─────────────────────
echo "[Chrome] 자동 업데이트 차단 중..."

# (a) Google Keystone (Software Update) 비활성화
defaults write com.google.Keystone.Agent checkInterval 0

# (b) 전역 업데이트 정책 — 엔터프라이즈 관리형 설정
sudo defaults write /Library/Preferences/com.google.Keystone UpdateDefault -int 0
sudo defaults write /Library/Preferences/com.google.Keystone IsManaged -bool true

# (c) Chrome 내부 업데이트 체크 비활성화
defaults write com.google.Chrome AutoUpdate -bool false

# (d) Keystone LaunchAgent / LaunchDaemon unload & 비활성화
KEYSTONE_AGENT="$HOME/Library/LaunchAgents/com.google.keystone.agent.plist"
KEYSTONE_DAEMON="/Library/LaunchDaemons/com.google.keystone.daemon.plist"
KEYSTONE_AGENT_SYS="/Library/LaunchAgents/com.google.keystone.agent.plist"
KEYSTONE_XPC_SYS="/Library/LaunchAgents/com.google.keystone.xpcservice.plist"

if [ -f "$KEYSTONE_AGENT" ]; then
  launchctl bootout gui/$(id -u) "$KEYSTONE_AGENT" 2>/dev/null || true
  launchctl disable "gui/$(id -u)/com.google.keystone.agent" 2>/dev/null || true
  echo "  - Keystone 유저 LaunchAgent 비활성화 완료"
fi

if [ -f "$KEYSTONE_DAEMON" ]; then
  sudo launchctl bootout system "$KEYSTONE_DAEMON" 2>/dev/null || true
  sudo launchctl disable "system/com.google.keystone.daemon" 2>/dev/null || true
  echo "  - Keystone LaunchDaemon 비활성화 완료"
fi

if [ -f "$KEYSTONE_AGENT_SYS" ]; then
  sudo launchctl bootout gui/$(id -u) "$KEYSTONE_AGENT_SYS" 2>/dev/null || true
  launchctl disable "gui/$(id -u)/com.google.keystone.agent" 2>/dev/null || true
  echo "  - Keystone 시스템 LaunchAgent 비활성화 완료"
fi

if [ -f "$KEYSTONE_XPC_SYS" ]; then
  sudo launchctl bootout gui/$(id -u) "$KEYSTONE_XPC_SYS" 2>/dev/null || true
  launchctl disable "gui/$(id -u)/com.google.keystone.xpcservice" 2>/dev/null || true
  echo "  - Keystone XPC Service 비활성화 완료"
fi

# (e) GoogleUpdater (신규 업데이터) 시스템 데몬 비활성화
GOOGLE_UPDATER_DAEMON="/Library/LaunchDaemons/com.google.GoogleUpdater.wake.system.plist"
if [ -f "$GOOGLE_UPDATER_DAEMON" ]; then
  sudo launchctl bootout system "$GOOGLE_UPDATER_DAEMON" 2>/dev/null || true
  sudo launchctl disable "system/com.google.GoogleUpdater.wake.system" 2>/dev/null || true
  echo "  - GoogleUpdater 시스템 데몬 비활성화 완료"
fi

# (f) Google Software Update / GoogleUpdater 디렉토리 권한 잠금
KEYSTONE_DIR="$HOME/Library/Google/GoogleSoftwareUpdate"
if [ -d "$KEYSTONE_DIR" ]; then
  chmod -R 000 "$KEYSTONE_DIR"
  echo "  - GoogleSoftwareUpdate 유저 디렉토리 권한 잠금 완료"
fi

KEYSTONE_DIR_SYS="/Library/Google/GoogleSoftwareUpdate"
if [ -d "$KEYSTONE_DIR_SYS" ]; then
  sudo chmod -R 000 "$KEYSTONE_DIR_SYS"
  echo "  - GoogleSoftwareUpdate 시스템 디렉토리 권한 잠금 완료"
fi

# GoogleUpdater 바이너리 잠금
find /Library/Google -name "GoogleUpdater" -type f 2>/dev/null | while read f; do
  sudo chmod 000 "$f"
  echo "  - 잠금: $f"
done

echo "[Chrome] 완료"
echo ""

# ── 2. Microsoft Edge 자동 업데이트 차단 ────────────────────
echo "[Edge] 자동 업데이트 차단 중..."

# (a) Microsoft AutoUpdate(MAU) 자동 체크 비활성화
defaults write com.microsoft.autoupdate2 HowToCheck -string "Manual"
defaults write com.microsoft.autoupdate2 DisableInsiderCheckbox -bool true

# (b) 엔터프라이즈 관리형 업데이트 정책
sudo defaults write /Library/Preferences/com.microsoft.autoupdate2 HowToCheck -string "Manual"
sudo defaults write /Library/Managed\ Preferences/com.microsoft.autoupdate2 HowToCheck -string "Manual" 2>/dev/null || true

# (c) Edge 자체 업데이트 정책
sudo defaults write /Library/Preferences/com.microsoft.EdgeUpdater UpdateDefault -int 0
sudo defaults write /Library/Managed\ Preferences/com.microsoft.edgemac AutoUpdate -bool false 2>/dev/null || true

# (d) Microsoft AutoUpdate LaunchAgent / LaunchDaemon unload & 비활성화
MAU_AGENTS=(
  "$HOME/Library/LaunchAgents/com.microsoft.update.agent.plist"
)
MAU_DAEMONS=(
  "/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist"
)

for plist in "${MAU_AGENTS[@]}"; do
  if [ -f "$plist" ]; then
    launchctl bootout gui/$(id -u) "$plist" 2>/dev/null || true
    launchctl disable "gui/$(id -u)/$(basename "$plist" .plist)" 2>/dev/null || true
    echo "  - $(basename "$plist") 비활성화 완료"
  fi
done

for plist in "${MAU_DAEMONS[@]}"; do
  if [ -f "$plist" ]; then
    sudo launchctl bootout system "$plist" 2>/dev/null || true
    sudo launchctl disable "system/$(basename "$plist" .plist)" 2>/dev/null || true
    echo "  - $(basename "$plist") 비활성화 완료"
  fi
done

echo "[Edge] 완료"
echo ""

# ── 결과 요약 ───────────────────────────────────────────────
echo "========================================"
echo " 자동 업데이트 차단 완료"
echo "========================================"
echo "  Chrome : $CHROME_VER (고정)"
echo "  Edge   : $EDGE_VER (고정)"
echo ""
echo "※ 복원하려면:"
echo "  Chrome — defaults delete com.google.Keystone.Agent checkInterval"
echo "           sudo defaults delete /Library/Preferences/com.google.Keystone UpdateDefault"
echo "           chmod -R 755 ~/Library/Google/GoogleSoftwareUpdate"
echo "  Edge   — defaults write com.microsoft.autoupdate2 HowToCheck -string 'AutomaticCheck'"
echo "           sudo defaults delete /Library/Preferences/com.microsoft.autoupdate2 HowToCheck"
