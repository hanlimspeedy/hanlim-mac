#!/bin/bash
set -e

echo "==> 부팅 사운드 끄기"

sudo nvram StartupMute=%01

echo ""
echo "완료: 부팅 사운드 비활성화됨"
echo "※ 원복: sudo nvram StartupMute=%00"
