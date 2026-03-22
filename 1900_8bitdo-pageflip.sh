#!/bin/bash
set -e

echo "==> 8BitDo Zero 2 페이지 넘기기 설정 (Karabiner-Elements)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# ───────────────────────────────────────────
# 1) Karabiner-Elements 설치 확인
# ───────────────────────────────────────────
if ! brew list --cask karabiner-elements &>/dev/null; then
  echo "오류: Karabiner-Elements가 설치되어 있지 않습니다."
  echo "먼저 0400_input-switch-shift-space.sh를 실행하세요."
  exit 1
fi
echo "  Karabiner-Elements 설치 확인됨"

# ───────────────────────────────────────────
# 2) Karabiner 설정 적용 (8BitDo 규칙 포함)
# ───────────────────────────────────────────
echo ""
echo "Karabiner 설정 적용 중..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.config/karabiner
cp "$SCRIPT_DIR/config/karabiner.json" ~/.config/karabiner/karabiner.json
echo "  karabiner.json 복사 완료 (8BitDo Zero 2 규칙 포함)"

echo ""
echo "========================================="
echo "완료: 8BitDo Zero 2 페이지 넘기기 설정"
echo "========================================="
echo ""
echo "※ 8BitDo Zero 2 연결 방법:"
echo "  1. R + Start 동시 누르기 (키보드 모드, LED 5회 깜빡)"
echo "  2. Select 3초 눌러 페어링 모드 진입"
echo "  3. macOS Bluetooth 설정에서 '8BitDo Zero 2' 페어링"
echo "  4. 재연결: Start 버튼만 누르면 자동 연결"
echo ""
echo "※ 버튼 매핑:"
echo "  - L 버튼 → Page Up (이전 페이지)"
echo "  - R 버튼 → Page Down (다음 페이지)"
echo ""
echo "※ 다른 키보드는 전혀 영향 없음 (device_if 조건)"
echo ""
echo "상세 가이드: config/8BITDO.md"
