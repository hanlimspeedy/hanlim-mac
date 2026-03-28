#!/bin/bash
set -e

echo "==> Claude Code Effort Level 설정 (high)"
echo "   ~/.claude/settings.json 에 effortLevel 기록"
echo ""

SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

mkdir -p "$SETTINGS_DIR"

# settings.json 이 이미 있으면 기존 값 병합, 없으면 새로 생성
if [ -f "$SETTINGS_FILE" ]; then
  # jq 가 있으면 병합, 없으면 덮어쓰기
  if command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq '. + {"effortLevel": "high"}' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    echo "--- 기존 settings.json 에 effortLevel 병합 완료"
  else
    echo '{"effortLevel":"high"}' > "$SETTINGS_FILE"
    echo "--- settings.json 덮어쓰기 완료 (jq 없음)"
  fi
else
  cat > "$SETTINGS_FILE" << 'JSON'
{
  "effortLevel": "high"
}
JSON
  echo "--- settings.json 새로 생성 완료"
fi

echo ""
echo "완료: Claude Code effort level = high"
echo ""
echo "설정 파일: $SETTINGS_FILE"
echo "현재 내용:"
cat "$SETTINGS_FILE"
echo ""
echo "※ 변경하려면: claude 실행 → /config 또는 직접 편집"
echo "※ 선택지: low | medium | high"
