#!/bin/bash
set -e

echo "==> 메뉴바에 볼륨 아이콘 항상 표시"

# macOS Tahoe에서는 defaults write로 제어 센터 설정이 반영되지 않음
# 시스템 설정 UI에서 수동 설정 필요
echo ""
echo "시스템 설정 > 제어 센터 화면을 엽니다..."
open "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension"

echo ""
echo "========================================="
echo "수동 설정 필요:"
echo "========================================="
echo ""
echo "  1. 열린 설정 화면에서 '사운드' 항목을 찾으세요"
echo "  2. 오른쪽 드롭다운을 클릭하세요"
echo "  3. '메뉴 막대에 항상 표시' 를 선택하세요"
echo ""
echo "※ 설정 후 즉시 적용됩니다."
