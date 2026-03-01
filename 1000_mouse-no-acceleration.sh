#!/bin/bash
set -e

echo "==> 마우스 윈도우 스타일 설정 (가속 끄기 + 속도 보정, 트랙패드 영향 없음)"

# 추적 속도 설정 (macOS 기본값: 1, 범위: 0~3)
defaults write .GlobalPreferences com.apple.mouse.scaling 1

# 가속 끄기 (macOS Sonoma+ com.apple.mouse.linear)
# true: 가속 비활성화 (선형 1:1 이동, 윈도우 스타일)
defaults write .GlobalPreferences com.apple.mouse.linear -bool true

echo ""
echo "완료: 마우스 윈도우 스타일 설정됨"
echo "  - 마우스: 추적 속도 기본(1) + 가속 끄기 (선형 이동)"
echo "  - 트랙패드: 기존 설정 유지"
echo ""
echo "※ 로그아웃 후 재로그인하면 적용됩니다."
echo "※ 속도 조절: defaults write .GlobalPreferences com.apple.mouse.scaling [0~3]"
echo "※ 원복: defaults delete .GlobalPreferences com.apple.mouse.linear"
