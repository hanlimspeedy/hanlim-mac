#!/bin/bash
# Claude Code에서 화면 캡쳐 권한 설정
# 시스템 설정에서 Terminal(또는 Claude Code 실행 앱)에 화면 녹화 권한 허용 필요
# 한 번만 설정하면 재부팅 후에도 유지됨

echo "==> 화면 녹화 권한 설정 열기"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

echo ""
echo "시스템 설정이 열렸습니다."
echo "Terminal (또는 Claude Code를 실행 중인 앱)에 화면 녹화 권한을 허용해주세요."
echo ""

# 권한 확인
sleep 5
if screencapture -x /tmp/test_capture.png 2>/dev/null; then
  rm -f /tmp/test_capture.png
  echo "완료: 화면 캡쳐 권한 정상"
else
  echo "아직 권한이 없습니다. 설정에서 허용 후 다시 실행해주세요."
fi
