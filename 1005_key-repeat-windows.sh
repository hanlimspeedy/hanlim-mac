#!/bin/bash
set -euo pipefail

# 키보드 반복 속도를 윈도우 기본값과 동일하게 맞춘다.
# 방향키/Backspace를 누르고 있을 때 커서 이동 속도가 윈도우처럼 빨라진다.
#
# 윈도우 기본값 (제어판 > 키보드):
#   재입력 시간(KeyboardDelay) 1 = 약 500ms
#   반복 속도(KeyboardSpeed)  31 = 초당 약 30회 (33ms)
# macOS 기본값: 첫 반복 500ms, 반복 간격 83ms (초당 약 12회)
#
# macOS KeyRepeat/InitialKeyRepeat 단위는 15ms 이다.
# defaults 값은 재로그인 후 적용되므로 hidutil 로 현재 세션에도 즉시 적용한다.

ACTION="apply"
WIN_DELAY=1
WIN_SPEED=31
MAC_DEFAULT_INITIAL_NS=500000000
MAC_DEFAULT_REPEAT_NS=83333333

usage() {
  echo "사용법: $0 [apply|status|reset] [--delay 0-3] [--speed 0-31]"
  echo ""
  echo "  apply    (기본) — 윈도우 키 반복 설정 적용 (즉시 + 재로그인 후에도 유지)"
  echo "  status          — 현재 설정 확인"
  echo "  reset           — macOS 기본값으로 복원"
  echo "  --delay 0-3     — 윈도우 '재입력 시간' (0=250ms, 1=500ms 기본, 2=750ms, 3=1000ms)"
  echo "  --speed 0-31    — 윈도우 '반복 속도' (0=초당 약 2.5회, 31=초당 약 30회 기본)"
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    apply|status|reset)
      ACTION="$1"
      shift
      ;;
  esac
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --delay|--speed)
      if [ "$#" -lt 2 ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "오류: $1 뒤에 숫자를 입력하세요."
        exit 1
      fi
      if [ "$1" = "--delay" ]; then
        WIN_DELAY="$2"
      else
        WIN_SPEED="$2"
      fi
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "오류: 알 수 없는 인자: $1"
      echo ""
      usage
      exit 1
      ;;
  esac
done

if [ "$WIN_DELAY" -gt 3 ]; then
  echo "오류: --delay 는 0~3 범위입니다."
  exit 1
fi
if [ "$WIN_SPEED" -gt 31 ]; then
  echo "오류: --speed 는 0~31 범위입니다."
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "오류: 이 스크립트는 macOS에서만 실행할 수 있습니다."
  exit 1
fi

show_status() {
  local initial_ns repeat_ns
  initial_ns="$(hidutil property --get HIDInitialKeyRepeat 2>/dev/null || echo 0)"
  repeat_ns="$(hidutil property --get HIDKeyRepeat 2>/dev/null || echo 0)"

  echo "--- 설정 확인 ---"
  echo "  InitialKeyRepeat:         $(defaults read -g InitialKeyRepeat 2>/dev/null || echo '미설정 (macOS 기본)')"
  echo "  KeyRepeat:                $(defaults read -g KeyRepeat 2>/dev/null || echo '미설정 (macOS 기본)')"
  echo "  ApplePressAndHoldEnabled: $(defaults read -g ApplePressAndHoldEnabled 2>/dev/null || echo '미설정 (macOS 기본: 악센트 팝업)')"
  if [ "$repeat_ns" -gt 0 ]; then
    echo "  현재 세션 첫 반복: $((initial_ns / 1000000))ms"
    echo "  현재 세션 반복 간격: $((repeat_ns / 1000000))ms (초당 약 $((1000000000 / repeat_ns))회)"
  fi
}

if [ "$ACTION" = "status" ]; then
  show_status
  exit 0
fi

if [ "$ACTION" = "reset" ]; then
  echo "==> 키 반복 설정을 macOS 기본값으로 복원"
  defaults delete -g InitialKeyRepeat 2>/dev/null || true
  defaults delete -g KeyRepeat 2>/dev/null || true
  defaults delete -g ApplePressAndHoldEnabled 2>/dev/null || true
  hidutil property --set "{\"HIDInitialKeyRepeat\":$MAC_DEFAULT_INITIAL_NS,\"HIDKeyRepeat\":$MAC_DEFAULT_REPEAT_NS}" >/dev/null
  echo ""
  show_status
  exit 0
fi

# 윈도우 재입력 시간: 0~3 → 250/500/750/1000ms → 15ms 단위 반올림
initial_ms=$(( (WIN_DELAY + 1) * 250 ))
initial_units=$(( (initial_ms + 7) / 15 ))

# 윈도우 반복 속도: 0~31 → 초당 2.5~30회 (선형) → 15ms 단위 반올림, 최소 1
repeat_units="$(awk -v s="$WIN_SPEED" 'BEGIN {
  u = int(1000 / (2.5 + s * 27.5 / 31) / 15 + 0.5)
  print (u < 1 ? 1 : u)
}')"

echo "==> 키 반복 속도 윈도우 스타일 설정 (재입력 시간 $WIN_DELAY, 반복 속도 $WIN_SPEED)"

# ───────────────────────────────────────────
# 1) 영구 설정 (재로그인 후에도 유지)
# ───────────────────────────────────────────
echo ""
echo "[1/3] 키 반복 영구 설정..."
defaults write -g InitialKeyRepeat -int "$initial_units"
defaults write -g KeyRepeat -int "$repeat_units"
echo "  InitialKeyRepeat = $initial_units ($((initial_units * 15))ms)"
echo "  KeyRepeat        = $repeat_units ($((repeat_units * 15))ms)"

# ───────────────────────────────────────────
# 2) 길게 누르기 악센트 팝업 끄기
#    윈도우처럼 글자 키를 누르고 있으면 반복 입력
# ───────────────────────────────────────────
echo ""
echo "[2/3] 길게 누르기 악센트 팝업 끄기..."
defaults write -g ApplePressAndHoldEnabled -bool false
echo "  ApplePressAndHoldEnabled = false"

# ───────────────────────────────────────────
# 3) 현재 세션 즉시 적용 (로그아웃 불필요)
#    Karabiner 가상 키보드를 포함한 모든 키보드에 적용된다.
# ───────────────────────────────────────────
echo ""
echo "[3/3] 현재 세션 즉시 적용..."
hidutil property --set "{\"HIDInitialKeyRepeat\":$((initial_units * 15000000)),\"HIDKeyRepeat\":$((repeat_units * 15000000))}" >/dev/null
echo "  hidutil HIDInitialKeyRepeat/HIDKeyRepeat 적용"

echo ""
show_status

echo ""
echo "========================================="
echo "완료: 키 반복 속도 윈도우 스타일"
echo "========================================="
echo ""
echo "  - 방향키/Backspace 누르고 있으면 윈도우와 같은 속도로 반복"
echo "  - 키 반복은 지금 바로 적용됨 (모든 앱)"
echo "  - 글자 키 길게 누르기 반복은 실행 중인 앱 재시작 후 적용"
echo ""
echo "※ 시스템 설정 > 키보드 슬라이더를 건드리면 이 값이 덮어써진다."
echo "※ 더 빠르게: $0 --delay 0   (첫 반복 250ms)"
echo "※ 원복:     $0 reset"
