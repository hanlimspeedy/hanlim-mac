#!/bin/bash
set -euo pipefail

# 마우스 포인터 크기/색상 윈도우 스타일 설정 안내
#
# 자동 설정 불가 (macOS Tahoe 26 확인):
#   - 설정 위치 com.apple.universalaccess 는 보호 도메인이라
#     defaults write 시 "Could not write domain" 으로 실패한다.
#   - 비공개 API SLSSetCursorScale 로 크기는 바뀌지만 재로그인 시 원복되고,
#     색상은 대응 API 가 없다.
# 따라서 현재 값을 보여주고 시스템 설정 화면을 열어 수동 설정을 안내한다.

ACTION="${1:-guide}"

usage() {
  echo "사용법: $0 [guide|status]"
  echo ""
  echo "  guide   (기본) — 설정 방법 안내 + 시스템 설정 화면 열기"
  echo "  status          — 현재 포인터 크기/색상 값 확인"
}

case "$ACTION" in
  guide|status) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "오류: 알 수 없는 동작: $ACTION"
    echo ""
    usage
    exit 1
    ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

read_ua() {
  defaults read com.apple.universalaccess "$1" 2>/dev/null | tr -s ' \n' ' ' || echo "미설정 (macOS 기본)"
}

show_status() {
  echo "--- 현재 설정 ---"
  echo "  포인터 크기 (mouseDriverCursorSize): $(read_ua mouseDriverCursorSize)"
  echo "  색상 변경 여부 (cursorIsCustomized): $(read_ua cursorIsCustomized)"
  echo "  채우기 색상 (cursorFill):            $(read_ua cursorFill)"
  echo "  외곽선 색상 (cursorOutline):         $(read_ua cursorOutline)"
}

if [ "$ACTION" = "status" ]; then
  show_status
  exit 0
fi

echo "==> 마우스 포인터 크기/색상 윈도우 스타일 설정 안내"
echo ""
echo "※ macOS 보호 설정이라 스크립트로 자동 변경할 수 없습니다. 아래대로 직접 설정하세요."
echo "  (한 번 설정하면 재부팅 후에도 유지, 사용자 계정별 설정)"
echo ""
show_status
echo ""
echo "--- 설정 방법 ---"
echo "  경로: 시스템 설정 > 손쉬운 사용 > 디스플레이 > 포인터"
echo "        (System Settings > Accessibility > Display > Pointer)"
echo ""
echo "  1. 포인터 크기 슬라이더 (보통 ~ 크게, 값 1.0 ~ 4.0)"
echo "     윈도우 포인터 크기와 대략 비교:"
echo "       윈도우 1  → 맨 왼쪽 '보통' (1.0)"
echo "       윈도우 3  → 1/3 지점 (2.0)"
echo "       윈도우 5  → 2/3 지점 (3.0)"
echo "       윈도우 7+ → 맨 오른쪽 '크게' (4.0)"
echo "     정확한 값은 '$0 status' 의 포인터 크기로 확인"
echo ""
echo "  2. 포인터 외곽 색상 → 채우기와 대비되는 색 (검정 또는 흰색)"
echo "  3. 포인터 채우기 색상 → 윈도우에서 쓰던 색 (예: 형광 연두)"
echo "     색상 코드 직접 입력: 색상 창 > 슬라이더 탭 > RGB > 16진수 색상"
echo ""
echo "  윈도우 '반전' 색상은 macOS에 없음 → 채우기 검정 + 외곽선 흰색 권장"
echo "  원복: 같은 화면 포인터 항목의 '재설정' 버튼"
echo ""
echo "  설정 후 확인: $0 status"
echo ""
echo "지금 설정 화면을 엽니다..."
open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display" 2>/dev/null || \
  open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension" 2>/dev/null || true
