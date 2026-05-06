#!/bin/bash
set -e

echo "==> Claude Code Dangerous Mode 실행기 설치 (ccd)"
echo "   /usr/local/bin/ccd 생성"
echo ""

INSTALL_PATH="/usr/local/bin/ccd"
TMPFILE=$(mktemp /tmp/ccd.XXXXXX)

cat > "$TMPFILE" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

find_claude() {
  local candidate=""

  if [ -n "${CLAUDE_CODE_BIN:-}" ] && [ -x "$CLAUDE_CODE_BIN" ]; then
    printf '%s\n' "$CLAUDE_CODE_BIN"
    return 0
  fi

  candidate="$(type -P claude 2>/dev/null || true)"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  local home="${HOME:-}"
  local candidates=(
    "$home/.local/bin/claude"
    "$home/.npm-global/bin/claude"
    "$home/.yarn/bin/claude"
    "$home/.bun/bin/claude"
    "$home/.volta/bin/claude"
    "$home/.asdf/shims/claude"
    "$home/Library/pnpm/claude"
    "$home/.local/share/pnpm/claude"
    "/opt/homebrew/bin/claude"
    "/usr/local/bin/claude"
  )

  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [ -d "$home/.nvm/versions/node" ]; then
    candidate="$(find "$home/.nvm/versions/node" -path '*/bin/claude' -print 2>/dev/null | sort -r | head -n 1 || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if [ -d "$home/.asdf/installs/nodejs" ]; then
    candidate="$(find "$home/.asdf/installs/nodejs" -path '*/bin/claude' -print 2>/dev/null | sort -r | head -n 1 || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if [ -d "$home/.fnm/node-versions" ]; then
    candidate="$(find "$home/.fnm/node-versions" -path '*/installation/bin/claude' -print 2>/dev/null | sort -r | head -n 1 || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}

CLAUDE_BIN="$(find_claude || true)"

if [ -z "$CLAUDE_BIN" ]; then
  echo "오류: 현재 사용자에서 Claude Code 실행 파일을 찾지 못했습니다." >&2
  echo "확인: claude 명령이 PATH에 있는지 보거나 CLAUDE_CODE_BIN=/path/to/claude 로 지정하세요." >&2
  exit 1
fi

exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"
SCRIPT

chmod 755 "$TMPFILE"

if [ -d "$(dirname "$INSTALL_PATH")" ] && [ -w "$(dirname "$INSTALL_PATH")" ]; then
  mv "$TMPFILE" "$INSTALL_PATH"
else
  sudo mkdir -p "$(dirname "$INSTALL_PATH")"
  sudo mv "$TMPFILE" "$INSTALL_PATH"
  sudo chmod 755 "$INSTALL_PATH"
fi

echo "완료: $INSTALL_PATH 설치됨"
echo ""
echo "사용법:"
echo "  ccd"
echo "  ccd --model opus"
echo ""
echo "주의: ccd는 Claude Code를 --dangerously-skip-permissions 로 실행합니다."
echo "      신뢰하는 작업 폴더에서만 사용하세요."
