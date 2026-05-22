#!/bin/bash
# codex / claude 의 외장 디스크 경로(CODEX_HOME, CLAUDE_CONFIG_DIR) 완전 해제.
# 기본 경로(~/.codex, ~/.claude)로 되돌린다.
# 반드시 그 맥의 GUI 터미널(Terminal.app / iTerm / Ghostty / Warp 등) 에서 실행.
# SSH 비대화 세션은 launchd GUI domain 과 분리될 수 있어 부분 해제만 됨.

set -u

UID_NUM=$(id -u)
GUI="gui/$UID_NUM"

echo "════════════════════════════════════════════════════════════"
echo " CODEX_HOME / CLAUDE_CONFIG_DIR 외장경로 해제"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "── BEFORE ──"
echo "  CODEX_HOME (launchctl)        = '$(launchctl getenv CODEX_HOME)'"
echo "  CLAUDE_CONFIG_DIR (launchctl) = '$(launchctl getenv CLAUDE_CONFIG_DIR)'"

echo ""
echo "── 1) plist 파일 모두 제거 (있다면) ──"
for f in \
  ~/Library/LaunchAgents/com.openai.codex.CODEX_HOME.plist \
  ~/Library/LaunchAgents/local.claude.config-dir.plist; do
  if [ -f "$f" ]; then
    echo "  삭제: $f"
    rm -f "$f"
  fi
done
# 혹시 다른 이름의 plist 가 같은 변수 박고 있나
extra=$(grep -rln 'CODEX_HOME\|CLAUDE_CONFIG_DIR\|/Volumes/ubuntu' \
  ~/Library/LaunchAgents/ /Library/LaunchAgents/ /Library/LaunchDaemons/ \
  2>/dev/null)
if [ -n "$extra" ]; then
  echo "  추가 발견:"
  echo "$extra" | sed 's/^/    /'
  echo "  (시스템/Library 영역의 plist 는 자동 삭제하지 않음 — 위 경로 수동 확인)"
fi

echo ""
echo "── 2) 로드된 LaunchAgent 도메인에서 bootout ──"
for label in com.openai.codex.CODEX_HOME local.claude.config-dir; do
  out=$(launchctl bootout "$GUI/$label" 2>&1)
  echo "  bootout $label : ${out:-OK}"
done

echo ""
echo "── 3) launchctl 환경에서 unset (현재 도메인 + GUI 도메인 둘 다) ──"
launchctl unsetenv CODEX_HOME && echo "  unset CODEX_HOME (current) OK"
launchctl unsetenv CLAUDE_CONFIG_DIR && echo "  unset CLAUDE_CONFIG_DIR (current) OK"
# SSH 비대화 세션의 unsetenv 는 gui/UID 도메인에 미반영 → asuser 로 GUI 쪽도 비움
sudo launchctl asuser "$UID_NUM" launchctl unsetenv CODEX_HOME 2>/dev/null && echo "  unset CODEX_HOME (gui/$UID_NUM) OK"
sudo launchctl asuser "$UID_NUM" launchctl unsetenv CLAUDE_CONFIG_DIR 2>/dev/null && echo "  unset CLAUDE_CONFIG_DIR (gui/$UID_NUM) OK"

echo ""
echo "── 4) shell init 잔재 확인 (있으면 직접 손봐야 함) ──"
hit_any=0
for f in ~/.zshenv ~/.zshrc ~/.zprofile ~/.zlogin ~/.bashrc ~/.bash_profile ~/.profile; do
  if [ -f "$f" ]; then
    hit=$(grep -nE 'CODEX_HOME|CLAUDE_CONFIG_DIR|/Volumes/ubuntu' "$f" 2>/dev/null)
    if [ -n "$hit" ]; then
      echo "  ! $f"
      echo "$hit" | sed 's/^/      /'
      hit_any=1
    fi
  fi
done
[ "$hit_any" = "0" ] && echo "  (없음)"

echo ""
echo "── AFTER ──"
echo "  CODEX_HOME (current domain)        = '$(launchctl getenv CODEX_HOME)'"
echo "  CLAUDE_CONFIG_DIR (current domain) = '$(launchctl getenv CLAUDE_CONFIG_DIR)'"
echo "  CODEX_HOME (gui/$UID_NUM)            = '$(sudo launchctl asuser "$UID_NUM" launchctl getenv CODEX_HOME 2>/dev/null)'"
echo "  CLAUDE_CONFIG_DIR (gui/$UID_NUM)     = '$(sudo launchctl asuser "$UID_NUM" launchctl getenv CLAUDE_CONFIG_DIR 2>/dev/null)'"
echo "  CODEX_HOME (이 쉘)                 = '${CODEX_HOME:-}'"
echo "  CLAUDE_CONFIG_DIR (이 쉘)          = '${CLAUDE_CONFIG_DIR:-}'"

echo ""
echo "════════════════════════════════════════════════════════════"
echo " 완료."
echo ""
echo "주의:"
echo " - 이 스크립트는 launchctl env (다음 자식 프로세스 부터 반영) 만 비운다."
echo " - 이미 떠 있는 터미널/앱 의 자체 환경변수는 안 바뀐다."
echo " - 따라서 ⌘Q 로 Terminal/iTerm 등 모든 터미널 종료 후 새로 열고 codex/claude 실행."
echo " - 그래도 \$CODEX_HOME / \$CLAUDE_CONFIG_DIR 가 다시 박혀있으면 → 재로그아웃."
echo ""
echo "그리고 1390_claude-config-dir.sh / 1640_codex-home.sh 를 다시 실행하면"
echo "같은 증상 재발한다. 외장 디스크 경로를 쓰지 않을 거면 그 두 스크립트는"
echo "실행하지 말 것."
echo "════════════════════════════════════════════════════════════"
