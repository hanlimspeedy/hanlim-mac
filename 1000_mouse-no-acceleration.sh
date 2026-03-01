#!/bin/bash
set -e

echo "==> 마우스 가속 끄기 (윈도우 스타일 선형 이동, 트랙패드 영향 없음)"

defaults write .GlobalPreferences com.apple.mouse.scaling -1

echo ""
echo "완료: 마우스 가속 비활성화됨"
echo "  - 마우스: 1:1 선형 이동 (윈도우 스타일)"
echo "  - 트랙패드: 기존 설정 유지"
echo ""
echo "※ 로그아웃 후 재로그인하면 적용됩니다."
echo "※ 원복: defaults write .GlobalPreferences com.apple.mouse.scaling 1"
