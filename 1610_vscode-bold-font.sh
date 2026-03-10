#!/bin/bash
set -e

echo "==> VS Code 굵은 폰트 설정 (Noto Sans KR Black, 눈 피로 감소)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# ───────────────────────────────────────────
# 1) Noto Sans KR 폰트 설치 (Homebrew tap)
# ───────────────────────────────────────────
echo ""
echo "[1/4] Noto Sans KR 폰트 설치..."

# Homebrew font tap 추가
if ! brew tap | grep -q "homebrew/cask-fonts" 2>/dev/null; then
  # 최신 Homebrew는 기본 cask에 폰트 포함
  true
fi

if ! brew list --cask font-noto-sans-cjk-kr &>/dev/null; then
  echo "  Noto Sans CJK KR 설치 중 (Black 포함, 전체 웨이트)..."
  brew install --cask font-noto-sans-cjk-kr
else
  echo "  Noto Sans CJK KR 이미 설치됨"
fi

# Noto Sans Mono CJK KR (터미널용)
if ! brew list --cask font-noto-sans-mono-cjk-kr &>/dev/null; then
  echo "  Noto Sans Mono CJK KR 설치 중 (터미널용)..."
  brew install --cask font-noto-sans-mono-cjk-kr
else
  echo "  Noto Sans Mono CJK KR 이미 설치됨"
fi

# ───────────────────────────────────────────
# 2) Custom UI Style 확장 설치
# ───────────────────────────────────────────
echo ""
echo "[2/4] Custom UI Style 확장 설치..."

if code --list-extensions 2>/dev/null | grep -q "subframe7536.custom-ui-style"; then
  echo "  Custom UI Style 이미 설치됨"
else
  echo "  Custom UI Style 설치 중..."
  code --install-extension subframe7536.custom-ui-style
fi

# ───────────────────────────────────────────
# 3) settings.json 설정
# ───────────────────────────────────────────
echo ""
echo "[3/4] VS Code settings.json 설정..."

SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

mkdir -p "$SETTINGS_DIR"

# 기존 설정 백업
if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  echo "  기존 설정 백업 완료"
fi

# 기존 settings.json 읽어서 폰트 관련 설정 병합
# python3으로 JSON 병합 (macOS 기본 내장)
python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/Library/Application Support/Code/User/settings.json")

# 기존 설정 읽기
try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# 굵은 폰트 설정 병합
bold_settings = {
    # ===== Editor: 굵기 900 =====
    "editor.fontFamily": "'Noto Sans KR Black'",
    "editor.fontWeight": "900",
    "editor.fontVariations": False,
    "editor.disableMonospaceOptimizations": True,
    "editor.fontSize": 16,
    "editor.lineHeight": 0,

    # ===== Terminal: 모노 글꼴(굵게) =====
    "terminal.integrated.fontFamily": "'Noto Sans Mono CJK KR', 'D2Coding', 'Cascadia Mono', 'Menlo', 'Monaco', monospace",
    "terminal.integrated.fontWeight": "bold",
    "terminal.integrated.fontWeightBold": "bold",

    # ===== WebView(Claude 패널 등)도 굵게 — Custom UI Style 확장 =====
    "custom-ui-style.font.sansSerif": "'Noto Sans KR Black','Noto Sans KR',-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif",
    "custom-ui-style.font.monospace": "'Noto Sans Mono CJK KR','D2Coding','Cascadia Mono','Menlo','Monaco','Courier New',monospace",
    "custom-ui-style.webview.monospaceSelector": [
        "pre", "code", ".code", ".codeblock", ".shiki", ".cm-editor"
    ],
    "custom-ui-style.webview.stylesheet": {
        ":root": {
            "--vscode-editor-font-family": "'Noto Sans KR Black','Noto Sans KR',sans-serif",
            "--vscode-editor-font-weight": "900"
        },
        "body, .markdown-body, .chat, .message, .message-text": {
            "font-family": "'Noto Sans KR Black','Noto Sans KR',sans-serif !important",
            "font-weight": "900 !important"
        },
        "pre, code, .code, .codeblock, .shiki, .cm-editor": {
            "font-family": "'Noto Sans Mono CJK KR','D2Coding','Cascadia Mono','Menlo','Monaco','Courier New',monospace !important",
            "font-weight": "700 !important"
        }
    }
}

settings.update(bold_settings)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)

print("  settings.json 업데이트 완료")
PYEOF

# ───────────────────────────────────────────
# 4) 적용
# ───────────────────────────────────────────
echo ""
echo "[4/4] 설정 적용..."
echo "  Custom UI Style: Reload 필요 → VS Code 재시작 시 자동 적용"

echo ""
echo "========================================="
echo "완료: VS Code 굵은 폰트 설정"
echo "========================================="
echo ""
echo "  - 에디터: Noto Sans KR Black (굵기 900)"
echo "  - 터미널: Noto Sans Mono CJK KR Bold"
echo "  - Claude 패널: Custom UI Style로 굵게 강제"
echo ""
echo "※ VS Code에서 Cmd+Shift+P → 'Custom UI Style: Reload' 실행 후"
echo "  VS Code를 완전히 재시작하세요."
