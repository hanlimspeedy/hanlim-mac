#!/bin/bash
set -e

echo "==> 스크롤 애니메이션 비활성화 (윈도우 스타일 즉시 페이지 이동)"

# ───────────────────────────────────────────
# 1) 시스템 전체 smooth scrolling 비활성화
#    Page Down/Up, Home, End 키보드 스크롤 시
#    애니메이션 없이 즉시 이동 (윈도우 동작과 동일)
# ───────────────────────────────────────────
echo ""
echo "[1/5] 시스템 전체 스크롤 애니메이션 비활성화..."
defaults write -g NSScrollAnimationEnabled -bool false
echo "  NSScrollAnimationEnabled = false"

# ───────────────────────────────────────────
# 2) Edge 브라우저 스크롤 애니메이션 비활성화
# ───────────────────────────────────────────
echo ""
echo "[2/5] Edge 스크롤 애니메이션 비활성화..."
defaults write com.microsoft.edgemac NSScrollAnimationEnabled -bool false
echo "  Edge NSScrollAnimationEnabled = false"

# ───────────────────────────────────────────
# 3) Chrome 브라우저 스크롤 애니메이션 비활성화
# ───────────────────────────────────────────
echo ""
echo "[3/5] Chrome 스크롤 애니메이션 비활성화..."
defaults write com.google.Chrome NSScrollAnimationEnabled -bool false
echo "  Chrome NSScrollAnimationEnabled = false"

# ───────────────────────────────────────────
# 4) Safari 브라우저 스크롤 애니메이션 비활성화
# ───────────────────────────────────────────
echo ""
echo "[4/5] Safari 스크롤 애니메이션 비활성화..."
# macOS Tahoe에서 Safari 도메인은 보호됨, 시스템 전체 설정(-g)이 Safari에도 적용됨
if defaults write com.apple.Safari NSScrollAnimationEnabled -bool false 2>/dev/null; then
  echo "  Safari NSScrollAnimationEnabled = false"
else
  echo "  Safari: 시스템 전체 설정(-g)으로 적용됨 (별도 설정 불필요)"
fi

# ───────────────────────────────────────────
# 5) 접근성: 동작 줄이기 활성화
#    Cmd+Tab 전환, Launchpad, 데스크톱 전환 등
#    전반적인 모션 애니메이션 감소
# ───────────────────────────────────────────
echo ""
echo "[5/5] 접근성 동작 줄이기 활성화..."
# macOS Tahoe에서는 com.apple.universalaccess가 보호되어 defaults write 불가
# 시스템 설정 UI에서 수동 설정 필요
if defaults write com.apple.universalaccess reduceMotion -bool true 2>/dev/null; then
  echo "  reduceMotion = true"
else
  echo "  ⚠ 시스템 보호로 자동 설정 불가 — 수동 설정 필요:"
  echo ""
  echo "    경로: 시스템 설정 > 손쉬운 사용 > 동작"
  echo "          (System Settings > Accessibility > Motion)"
  echo ""
  echo "    설정: '동작 줄이기' 토글을 켜기 (ON)"
  echo ""
  echo "    효과: Cmd+Tab 전환, 데스크톱 전환 등 모션 애니메이션 감소"
  echo ""
  echo "  지금 설정 화면을 엽니다..."
  open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Motion" 2>/dev/null || \
    open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension" 2>/dev/null || true
fi

# ───────────────────────────────────────────
# 검증
# ───────────────────────────────────────────
echo ""
echo "--- 설정 확인 ---"
echo "  시스템 전체: $(defaults read -g NSScrollAnimationEnabled 2>/dev/null)"
echo "  Edge:       $(defaults read com.microsoft.edgemac NSScrollAnimationEnabled 2>/dev/null)"
echo "  Chrome:     $(defaults read com.google.Chrome NSScrollAnimationEnabled 2>/dev/null)"
echo "  Safari:     $(defaults read com.apple.Safari NSScrollAnimationEnabled 2>/dev/null || echo '시스템 전체 설정 적용')"
echo "  동작 줄이기: $(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || echo '수동 설정 필요')"

echo ""
echo "========================================="
echo "완료: 스크롤 애니메이션 비활성화"
echo "========================================="
echo ""
echo "  - Page Down/Up: 애니메이션 없이 즉시 이동 (윈도우 동일)"
echo "  - Edge, Chrome, Safari: 스크롤 애니메이션 비활성화"
echo "  - 전반적 모션 애니메이션 감소 (수동 설정 시)"
echo ""
echo "※ 로그아웃 후 재로그인하면 완전히 적용됩니다."
echo "  (실행 중인 앱은 재시작 필요)"
echo ""
echo "복원 방법:"
echo "  defaults write -g NSScrollAnimationEnabled -bool true"
echo "  defaults write com.microsoft.edgemac NSScrollAnimationEnabled -bool true"
echo "  defaults write com.google.Chrome NSScrollAnimationEnabled -bool true"
echo "  defaults write com.apple.Safari NSScrollAnimationEnabled -bool true"
echo "  defaults write com.apple.universalaccess reduceMotion -bool false"
