#!/bin/bash
set -e

echo "==> 폰트 스무딩 활성화 (LG 43UN700-B BGR 패널 텍스트 가독성 개선)"

# ───────────────────────────────────────────
# LG 43UN700-B는 BGR 서브픽셀 배열 사용
# macOS Mojave 이후 서브픽셀 안티앨리어싱이 기본 비활성화됨
# 이를 다시 활성화하여 텍스트 가독성을 높임
#
# AppleFontSmoothing 값:
#   0 = 비활성화
#   1 = 약하게
#   2 = 중간 (권장)
#   3 = 강하게
# ───────────────────────────────────────────

echo ""
echo "[1/1] 폰트 스무딩 설정..."
defaults write -g AppleFontSmoothing -int 2
echo "  AppleFontSmoothing = 2 (중간)"

# ───────────────────────────────────────────
# 검증
# ───────────────────────────────────────────
echo ""
echo "--- 설정 확인 ---"
echo "  AppleFontSmoothing: $(defaults read -g AppleFontSmoothing 2>/dev/null)"

echo ""
echo "========================================="
echo "완료: 폰트 스무딩 활성화"
echo "========================================="
echo ""
echo "  - 대상 모니터: LG 43UN700-B (43인치 4K, BGR 서브픽셀)"
echo "  - 폰트 스무딩 강도: 중간 (2)"
echo "  - macOS는 BGR/RGB 선택 기능 없음 (RGB 기준 렌더링)"
echo ""
echo "※ 로그아웃 후 재로그인하면 완전히 적용됩니다."
echo ""
echo "강도 조절:"
echo "  defaults write -g AppleFontSmoothing -int 1  # 약하게"
echo "  defaults write -g AppleFontSmoothing -int 2  # 중간 (권장)"
echo "  defaults write -g AppleFontSmoothing -int 3  # 강하게"
echo ""
echo "복원 방법:"
echo "  defaults delete -g AppleFontSmoothing"
