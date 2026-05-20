#!/bin/bash
set -e

echo "==> Tailscale 설치 (WireGuard 기반 메시 VPN)"

# Homebrew 환경 로드
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

if ! brew list --cask tailscale-app &>/dev/null; then
  echo "Tailscale 설치 중..."
  brew install --cask tailscale-app
elif [ ! -d "/Applications/Tailscale.app" ]; then
  echo "Tailscale Cask는 등록되어 있으나 /Applications/Tailscale.app 없음 — 재설치"
  brew reinstall --cask tailscale-app
else
  echo "Tailscale 이미 설치됨"
fi

echo ""
echo "완료: Tailscale 설치됨"
echo "  - WireGuard 기반 메시 VPN (P2P 연결)"
echo "  - 메뉴바 아이콘에서 노드 접속/관리"
echo "  - 개인 사용 무료 (최대 100대 디바이스)"
echo ""
echo "※ 최초 실행: open -a Tailscale"
echo "※ 로그인 후 메뉴바에서 다른 노드 IP/MagicDNS 로 접속 가능"
echo "※ https://tailscale.com/"
