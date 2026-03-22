#!/bin/bash
set -e

echo "==> 배터리 충전 80% 제한 설정 (batt - LaunchDaemon)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# ───────────────────────────────────────────
# 1) 기존 actuallymentor/battery 제거 (설치된 경우만)
# ───────────────────────────────────────────
if brew list --cask battery &>/dev/null || [ -f /usr/local/co.palokaj.battery/battery ]; then
  echo ""
  echo "[1/4] 기존 actuallymentor/battery 제거..."

  # maintain 중지
  battery maintain stop 2>/dev/null || true

  # battery.app 종료
  osascript -e 'quit app "battery"' 2>/dev/null || true
  sleep 1

  # LaunchAgent 언로드 및 삭제
  launchctl bootout "gui/$(id -u)/com.battery.app" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/battery.plist"

  # CLI 및 지원 파일 삭제
  sudo rm -rf /usr/local/co.palokaj.battery 2>/dev/null || true
  sudo rm -f /usr/local/bin/battery 2>/dev/null || true
  rm -rf "$HOME/.battery" 2>/dev/null || true
  rm -rf "$HOME/Library/Application Support/battery" 2>/dev/null || true
  rm -rf "$HOME/Library/Caches/co.palokaj.battery"* 2>/dev/null || true
  rm -rf "$HOME/Library/HTTPStorages/co.palokaj.battery" 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/co.palokaj.battery.plist" 2>/dev/null || true

  # sudoers 제거
  sudo rm -f /private/etc/sudoers.d/battery 2>/dev/null || true

  # cask 제거
  brew uninstall --cask battery 2>/dev/null || true

  echo "  기존 battery 제거 완료"
else
  echo ""
  echo "[1/4] 기존 actuallymentor/battery 없음 (건너뜀)"
fi

# ───────────────────────────────────────────
# 2) batt 설치 (charlie0129/batt)
#    Go로 작성된 Apple Silicon 전용, LaunchDaemon 아키텍처
# ───────────────────────────────────────────
echo ""
echo "[2/4] batt 설치..."

if ! brew list batt &>/dev/null; then
  brew install batt
else
  echo "  batt 이미 설치됨, 최신 버전 확인..."
  brew upgrade batt 2>/dev/null || true
fi

echo "  버전: $(batt --version 2>/dev/null || batt version 2>/dev/null || echo '확인 불가')"

# ───────────────────────────────────────────
# 3) LaunchDaemon 등록 및 80% 충전 제한 설정
# ───────────────────────────────────────────
echo ""
echo "[3/4] LaunchDaemon 등록 및 충전 제한 설정..."

# batt LaunchDaemon 시작
# Homebrew 설치 버전은 brew services로 데몬 관리
if sudo launchctl list 2>/dev/null | grep -q "cc.chlc.batt"; then
  echo "  batt 데몬 이미 실행 중"
else
  sudo brew services start batt
fi
sleep 2

# 80% 충전 제한 설정
batt limit 80

echo "  80% 충전 제한 설정 완료"

# ───────────────────────────────────────────
# 4) 검증
# ───────────────────────────────────────────
echo ""
echo "[4/4] 설정 검증..."

# batt 상태 확인
echo ""
echo "--- batt 상태 ---"
batt status 2>&1 || true

# LaunchDaemon 동작 확인
echo ""
echo "--- LaunchDaemon 확인 ---"
DAEMON_PLIST=$(ls /Library/LaunchDaemons/*batt* 2>/dev/null | head -1)
if [ -n "$DAEMON_PLIST" ]; then
  echo "  파일: $DAEMON_PLIST"
  ls -la "$DAEMON_PLIST"
else
  echo "  경고: LaunchDaemon plist 파일을 찾을 수 없음"
fi

if sudo launchctl list 2>/dev/null | grep -q "batt"; then
  echo "  launchctl: 실행 중"
else
  echo "  경고: launchctl에서 batt 데몬을 찾을 수 없음"
fi

# 현재 배터리 상태
echo ""
echo "--- 배터리 하드웨어 상태 ---"
CHARGE=$(pmset -g batt 2>/dev/null | grep -o '[0-9]*%' | head -1)
CHARGING=$(pmset -g batt 2>/dev/null | grep -o 'charging\|discharging\|charged\|not charging\|AC attached' | head -1)
echo "  충전량: ${CHARGE:-확인 불가}"
echo "  상태: ${CHARGING:-확인 불가}"

echo ""
echo "========================================="
echo "완료: 배터리 충전 80% 제한 설정 (batt)"
echo "========================================="
echo ""
echo "  - LaunchDaemon으로 동작 (로그아웃/슬립에도 유지)"
echo "  - 80% 이상 충전 차단, 이하로 내려가면 자동 충전"
echo "  - 재부팅 후에도 자동 실행"
echo ""
echo "검증 방법:"
echo "  1. 로그아웃 후 재로그인 → batt status 확인"
echo "  2. 재부팅 → batt status 확인"
echo ""
echo "유용한 명령어:"
echo "  batt status              # 현재 상태 확인"
echo "  sudo batt limit 80      # 충전 제한 설정"
echo "  sudo batt limit 100     # 충전 제한 해제"
echo "  sudo batt uninstall     # batt 데몬 제거"
echo ""
echo "롤백 (문제 발생 시):"
echo "  sudo brew services stop batt && brew uninstall batt"
echo ""
echo "※ GitHub: https://github.com/charlie0129/batt"
