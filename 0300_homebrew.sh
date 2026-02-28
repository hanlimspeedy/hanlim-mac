#!/bin/bash
set -e

echo "==> Homebrew 설치 중..."

if command -v brew &>/dev/null; then
  echo "이미 설치됨"
  exit 0
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon 경로 설정
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
fi

echo "완료: brew $(brew --version | head -1)"
