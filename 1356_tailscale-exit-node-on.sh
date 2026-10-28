#!/bin/bash
set -euo pipefail

# Tailscale exit node 사용: 인터넷 트래픽을 다른 PC를 거쳐 그 PC의 IP로 내보낸다.
# 필요할 때만 켜고, 끝나면 ./1355_tailscale-exit-node-off.sh 로 해제한다.

TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/tailscale"
# exit node로 쓸 PC. 후보: tailscale exit-node list 의 HOSTNAME
EXIT_NODE="big-245"

echo "==> Tailscale exit node 사용: $EXIT_NODE"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if [ ! -x "$TAILSCALE" ]; then
  echo "오류: Tailscale이 없습니다. 먼저 ./1350_tailscale.sh 를 실행하세요."
  exit 1
fi

# 꺼져 있으면 기존 설정 그대로 연결한다. 플래그 없는 up은 설정을 바꾸지 않는다.
# exit node 이름은 연결된 상태에서만 확인할 수 있으므로 먼저 연결한다.
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

# 공유기 내부망(SMB, 프린터 등)은 exit node를 거치지 않고 직접 접근한다.
"$TAILSCALE" set --exit-node="$EXIT_NODE" --exit-node-allow-lan-access=true

# 검증
json="$("$TAILSCALE" status --json)"
if [ "$(jq -r '.ExitNodeStatus.Online == true' <<<"$json")" != true ]; then
  echo "오류: exit node $EXIT_NODE 가 오프라인입니다. 그 PC의 Tailscale 연결을 확인하세요."
  echo "※ 해제: ./1355_tailscale-exit-node-off.sh"
  exit 1
fi
sleep 2
public_ip="$(curl -s -m 8 https://ipinfo.io/json | jq -r '"\(.ip) (\(.org), \(.city))"' 2>/dev/null || true)"

echo ""
echo "완료: exit node 사용 중"
echo "  - exit node: $(jq -r '[.Peer[] | select(.ExitNode) | "\(.DNSName | split(".")[0]) (\(.TailscaleIPs[0]))"] | first' <<<"$json")"
echo "  - 공인 IP: ${public_ip:-확인 실패}"
echo "※ 해제: ./1355_tailscale-exit-node-off.sh"
