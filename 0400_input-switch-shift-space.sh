#!/bin/bash
set -e

echo "==> Shift+Space 한영전환 설정 (macOS 기본 설정)"

# 입력 소스 전환 단축키를 Shift+Space로 변경
# 60 = 이전 입력 소스, 61 = 다음 입력 소스 (비활성)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
  -dict-add 60 '{ enabled = 1; value = { parameters = (32, 49, 131072); type = standard; }; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
  -dict-add 61 '{ enabled = 0; value = { parameters = (32, 49, 131072); type = standard; }; }'

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null

echo "완료: Shift+Space 한영전환 (로그아웃 후 확실히 적용)"
