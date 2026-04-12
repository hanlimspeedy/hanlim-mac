#!/bin/bash
set -e

echo "==> 8BitDo Zero 2 페이지 넘기기 (Swift CLI 빌드)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/8bitdo-pageflip/main.swift"
BIN="$SCRIPT_DIR/8bitdo-pageflip/8bitdo-pageflip"

if [ ! -f "$SRC" ]; then
  echo "오류: $SRC 가 없습니다."
  exit 1
fi

if ! command -v swiftc &>/dev/null; then
  echo "오류: swiftc가 없습니다. 먼저 0100_xcode-cli-tools.sh 실행."
  exit 1
fi

echo "  swiftc로 빌드 중..."
swiftc -O "$SRC" -o "$BIN"
echo "  빌드 완료: $BIN"

echo ""
echo "========================================="
echo "완료: 8BitDo Zero 2 PageFlip"
echo "========================================="
echo ""
echo "※ 8BitDo Zero 2 연결 방법 (게임패드 모드):"
echo "  1. A + Start 동시 누르기 (LED 3회 깜빡)"
echo "  2. Select 3초 길게 → 페어링 모드"
echo "  3. macOS Bluetooth에서 '8BitDo Zero 2' 페어링"
echo "  4. 재연결: Start 버튼만 누르면 자동 연결"
echo ""
echo "※ 실행:"
echo "  $BIN"
echo ""
echo "※ 버튼 매핑:"
echo "  - 물리 A / R숄더 → Page Up"
echo "  - 물리 Y / L숄더 → Page Down"
echo "  - 물리 X         → ← (뒤로)"
echo "  - 물리 B         → → (앞으로)"
echo ""
echo "상세 가이드: config/8BITDO.md"
