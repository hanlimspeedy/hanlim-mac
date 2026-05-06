#!/bin/bash
set -e

echo "==> Claude Code 설정 디렉터리 리디렉트"
echo "   CLAUDE_CONFIG_DIR=/Volumes/ubuntu/.claude (Samba 공유)"
echo ""

LABEL="local.claude.config-dir"
TARGET_DIR="/Volumes/ubuntu/.claude"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

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
        <string>CLAUDE_CONFIG_DIR</string>
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
launchctl setenv CLAUDE_CONFIG_DIR "$TARGET_DIR"
echo "--- 현재 세션에 환경 변수 즉시 적용"

echo ""
echo "완료: CLAUDE_CONFIG_DIR = $(launchctl getenv CLAUDE_CONFIG_DIR)"
echo ""
echo "※ 이후 claude 실행 시 ~/.claude 가 아닌 $TARGET_DIR 를 사용합니다."
echo "※ 해제하려면:"
echo "   launchctl bootout ${GUI_DOMAIN}/${LABEL}"
echo "   rm $PLIST"
