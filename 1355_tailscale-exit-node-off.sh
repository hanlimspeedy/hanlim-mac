#!/bin/bash
set -euo pipefail

# Tailscale exit node 해제 (평소 상태).
# exit node를 쓰면 모든 인터넷 트래픽이 그 PC를 거쳐 나가 느려진다.
# Tailscale 연결(다른 노드 접속, VNC 등)은 그대로 유지한다.
# 다시 켜기: ./1356_tailscale-exit-node-on.sh

TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/tailscale"

echo "==> Tailscale exit node 해제"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if [ ! -x "$TAILSCALE" ]; then
  echo "오류: Tailscale이 없습니다. 먼저 ./1350_tailscale.sh 를 실행하세요."
  exit 1
fi

# 연결 전에 먼저 해제해 잠깐이라도 exit node로 나가지 않게 한다.
"$TAILSCALE" set --exit-node=

# 꺼져 있으면 기존 설정 그대로 연결한다. 플래그 없는 up은 설정을 바꾸지 않는다.
state="$("$TAILSCALE" status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')"
case "$state" in
  Running)
    ;;
  Stopped)
    echo "Tailscale 연결 중..."
    "$TAILSCALE" up
    ;;
  *)
    echo "오류: Tailscale 상태가 $state 입니다. 메뉴바 Tailscale 아이콘에서 로그인/연결하세요."
    exit 1
    ;;
esac

# 검증
json="$("$TAILSCALE" status --json)"
if [ "$(jq -r '.ExitNodeStatus != null' <<<"$json")" = true ]; then
  echo "오류: exit node가 아직 설정되어 있습니다."
  exit 1
fi
public_ip="$(curl -s -m 8 https://ipinfo.io/json | jq -r '"\(.ip) (\(.org), \(.city))"' 2>/dev/null || true)"

echo ""
echo "완료: exit node 사용 안 함"
echo "  - Tailscale: $(jq -r '.BackendState' <<<"$json")"
echo "  - 공인 IP: ${public_ip:-확인 실패}"
