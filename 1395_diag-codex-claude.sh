#!/bin/bash
# 진단용 일회성 스크립트: codex / claude CLI 가 "멈춤" 보이는 원인 파악
# 사용자 GUI 터미널에서 직접 실행 → diag-results/<host>.txt 에 저장 → git push 까지.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/diag-results"
mkdir -p "$OUT_DIR"

HOST_RAW="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
HOST="$(printf '%s' "$HOST_RAW" | tr -c 'A-Za-z0-9._-' '_')"
OUT="$OUT_DIR/${HOST}.txt"

{
echo "════════════════════════════════════════════════════════════"
echo " codex / claude 환경 진단"
echo "  host = $HOST_RAW   user = $USER"
echo "  date = $(date '+%F %T %z')"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "── [1] 터미널 환경 ────────────────────────────"
echo "TERM             = ${TERM:-}"
echo "TERM_PROGRAM     = ${TERM_PROGRAM:-}"
echo "TERM_PROGRAM_VER = ${TERM_PROGRAM_VERSION:-}"
echo "COLS x LINES     = $(tput cols 2>/dev/null) x $(tput lines 2>/dev/null)"
echo "LANG             = ${LANG:-}"
echo "LC_ALL           = ${LC_ALL:-}"
echo "SHELL            = ${SHELL:-}"
echo "부모 프로세스    = $(ps -o comm= -p $PPID 2>/dev/null)"
echo "stty 상태(앞 3줄):"
stty -a 2>/dev/null | head -3 | sed 's/^/   /'

echo ""
echo "── [2] launchctl 환경 ────────────────────────────"
echo "CODEX_HOME (launchctl)        = '$(launchctl getenv CODEX_HOME)'"
echo "CLAUDE_CONFIG_DIR (launchctl) = '$(launchctl getenv CLAUDE_CONFIG_DIR)'"

echo ""
echo "── [3] 쉘 환경변수 ────────────────────────────"
echo "CODEX_HOME (shell)        = '${CODEX_HOME:-}'"
echo "CLAUDE_CONFIG_DIR (shell) = '${CLAUDE_CONFIG_DIR:-}'"
echo "PATH 앞부분:"
echo "${PATH:-}" | tr ':' '\n' | head -5 | sed 's/^/   /'

echo ""
echo "── [4] 디렉토리 존재 여부 ────────────────────────────"
for d in "$HOME/.codex" "$HOME/.claude" /Volumes/ubuntu /Volumes/ubuntu/.codex /Volumes/ubuntu/.claude; do
  if [ -e "$d" ]; then
    echo "  ✓ $d  $(ls -ld "$d" 2>/dev/null | awk '{print $1,$3,$4,$5}')"
  else
    echo "  ✗ $d  (없음)"
  fi
done

echo ""
echo "── [5] /Volumes 마운트 ────────────────────────────"
mount | grep -E 'Volumes|ubuntu' || echo "  (외장 볼륨 마운트 없음)"

echo ""
echo "── [6] LaunchAgents 잔재 ────────────────────────────"
echo "~/Library/LaunchAgents:"
ls ~/Library/LaunchAgents/ 2>/dev/null | sed 's/^/   /' || echo "   (디렉토리 없음)"
echo "CODEX/CLAUDE/Volumes 키 있는 plist:"
hits=$(grep -rln 'CODEX_HOME\|CLAUDE_CONFIG_DIR\|/Volumes/ubuntu' \
  ~/Library/LaunchAgents/ /Library/LaunchAgents/ /Library/LaunchDaemons/ \
  2>/dev/null)
if [ -n "$hits" ]; then
  echo "$hits" | sed 's/^/   ! /'
else
  echo "   (없음)"
fi

echo ""
echo "── [7] shell init 파일 잔재 ────────────────────────────"
hit_any=0
for f in ~/.zshenv ~/.zshrc ~/.zprofile ~/.zlogin ~/.bashrc ~/.bash_profile ~/.profile \
         /etc/zshenv /etc/zshrc /etc/zprofile /etc/profile /etc/bashrc; do
  if [ -f "$f" ]; then
    hit=$(grep -nE 'CODEX_HOME|CLAUDE_CONFIG_DIR|/Volumes/ubuntu' "$f" 2>/dev/null)
    if [ -n "$hit" ]; then
      echo "   ! $f"
      echo "$hit" | sed 's/^/      /'
      hit_any=1
    fi
  fi
done
[ "$hit_any" = "0" ] && echo "   (없음)"

echo ""
echo "── [8] 터미널 앱 plist 안에 환경변수 ────────────────────────────"
found_any=0
for app in com.apple.Terminal com.googlecode.iterm2 com.mitchellh.ghostty dev.warp.Warp-Stable com.termius-dmg.termius; do
  out=$(defaults read "$app" 2>/dev/null | grep -iE 'codex|claude|ubuntu|/volumes' | head -5)
  if [ -n "$out" ]; then
    echo "  ! $app"
    echo "$out" | sed 's/^/     /'
    found_any=1
  fi
done
[ "$found_any" = "0" ] && echo "   (없음)"

echo ""
echo "── [9] codex / claude 바이너리 ────────────────────────────"
echo "which codex  = $(which codex 2>&1)"
echo "which claude = $(which claude 2>&1)"
codex --version 2>&1 | sed 's/^/  codex: /'
claude --version 2>&1 | sed 's/^/  claude: /'

echo ""
echo "── [10] 현재 실행 중인 codex/claude 프로세스 ────────────────────────────"
ps -axo pid,ppid,user,command 2>/dev/null \
  | grep -E 'codex|claude' | grep -v grep | head -10 \
  | sed 's/^/   /' || echo "   (없음)"

echo ""
echo "════════════════════════════════════════════════════════════"
echo " 저장 위치: $OUT"
echo "════════════════════════════════════════════════════════════"
} 2>&1 | tee "$OUT"

# git 커밋 + push (실패해도 진단 결과는 파일에 남음)
echo ""
echo "── git add / commit / push ──────────────────────────"
cd "$SCRIPT_DIR" || exit 0
git add "diag-results/${HOST}.txt" 2>&1
git commit -m "diag: codex/claude env on ${HOST_RAW}" 2>&1 | tail -5
git push 2>&1 | tail -5
echo ""
echo "끝. 다른 쪽에서 git pull 하면 ${OUT#$SCRIPT_DIR/} 확인 가능."
