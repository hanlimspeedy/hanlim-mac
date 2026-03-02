#!/bin/bash
set -e

echo "==> Claude Code Compose Bar 설치 (한글 입력용)"
echo "   tmux + micro 기반 별도 입력창"
echo ""

# tmux 설치
if ! command -v tmux &>/dev/null; then
  echo "--- tmux 설치 중..."
  if command -v brew &>/dev/null; then
    brew install tmux
  elif command -v apt &>/dev/null; then
    sudo apt install -y tmux
  else
    echo "오류: brew 또는 apt 패키지 매니저가 필요합니다."
    exit 1
  fi
else
  echo "--- tmux 이미 설치됨: $(tmux -V)"
fi

# micro 설치
if ! command -v micro &>/dev/null; then
  echo "--- micro 에디터 설치 중..."
  if command -v brew &>/dev/null; then
    brew install micro
  elif command -v apt &>/dev/null; then
    sudo apt install -y micro
  else
    echo "오류: brew 또는 apt 패키지 매니저가 필요합니다."
    exit 1
  fi
else
  echo "--- micro 이미 설치됨: $(micro --version | head -1)"
fi

# claude-compose 스크립트 설치
echo "--- claude-compose 스크립트 설치..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-compose << 'SCRIPT'
#!/bin/bash
# Claude Code 한글 입력용 Compose Bar
# tmux 하단 분할창에서 micro로 텍스트 작성 후 원래 창에 붙여넣기
#
# 사용법: claude-compose <원래_pane_id>
# 단축키: tmux 안에서 Ctrl+D

ORIGINAL_PANE="$1"
TMPFILE=$(mktemp /tmp/claude-compose.XXXXXX)

micro -autosave 1 "$TMPFILE"

if [ -s "$TMPFILE" ]; then
  tmux load-buffer "$TMPFILE"
  tmux paste-buffer -t "$ORIGINAL_PANE"
fi

rm -f "$TMPFILE"
SCRIPT
chmod +x ~/.local/bin/claude-compose

# PATH 확인
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  echo "--- PATH에 ~/.local/bin 추가됨 (.bashrc)"
fi

# tmux 설정
echo "--- tmux Compose Bar 단축키 설정..."
TMUX_CONF="$HOME/.tmux.conf"
COMPOSE_BIND='bind -T root C-d run-shell '"'"'tmux split-window -v -l 8 "claude-compose #{pane_id}"'"'"''

# 마우스 스크롤 활성화
if [ -f "$TMUX_CONF" ] && grep -q "mouse on" "$TMUX_CONF"; then
  echo "--- tmux mouse 이미 설정됨"
else
  echo "" >> "$TMUX_CONF"
  echo "# 마우스 스크롤로 화면 출력 스크롤" >> "$TMUX_CONF"
  echo "set -g mouse on" >> "$TMUX_CONF"
fi

# Compose Bar 단축키
if [ -f "$TMUX_CONF" ] && grep -q "claude-compose" "$TMUX_CONF"; then
  echo "--- tmux Compose Bar 이미 설정됨"
else
  echo "" >> "$TMUX_CONF"
  echo "# Claude Code Compose Bar (Ctrl+D)" >> "$TMUX_CONF"
  echo "$COMPOSE_BIND" >> "$TMUX_CONF"
fi

# 현재 tmux 세션에 적용
if [ -n "$TMUX" ]; then
  tmux source-file "$TMUX_CONF" 2>/dev/null
  echo "--- 현재 tmux 세션에 적용됨"
fi

echo ""
echo "완료: Claude Code Compose Bar 설치됨"
echo ""
echo "사용법:"
echo "  1. tmux 실행: tmux"
echo "  2. Claude Code 실행: claude"
echo "  3. Ctrl+D → 하단에 입력창(micro) 열림"
echo "  4. 한글/영문 입력 후 Ctrl+Q로 종료"
echo "  5. 입력한 텍스트가 Claude Code에 자동 붙여넣기됨"
echo ""
echo "※ macOS: brew install tmux micro"
echo "※ Ubuntu: apt install tmux micro"
