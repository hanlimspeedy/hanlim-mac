#!/bin/bash
set -e

echo "==> Homebrew 다중 사용자 공유 설정 (admin 그룹)"

# Homebrew 설치 확인
if [ ! -d /opt/homebrew ]; then
  echo "오류: /opt/homebrew 가 없습니다. 먼저 0300_homebrew.sh를 실행하세요."
  exit 1
fi

# 다른 계정이 brew로 새로 만든 파일/폴더는 admin 그룹 쓰기 권한이 없다(umask 022).
# 하나라도 있으면 이 계정의 brew 업데이트가 중간에 실패해 Homebrew 코드가 반만 갱신된다.
# locks 폴더만 보면 이를 놓치므로 전체에서 그룹/쓰기 권한이 빠진 항목을 찾는다.
# .git 안의 파일(index, objects 등)은 git이 항상 새 파일로 바꿔 쓰므로 폴더 권한만 있으면 되고,
# brew/git 명령을 실행할 때마다 그룹 쓰기 권한 없이 다시 생기므로 검사에서 뺀다.
find_not_shared() {
  find /opt/homebrew ! -type l \( -type d -o ! -path '*/.git/*' \) \
    \( ! -group admin -o ! -perm -g+w \) -print -quit 2>/dev/null
}

fix_permissions() {
  local not_shared
  not_shared="$(find_not_shared)"
  if [ -n "$not_shared" ]; then
    echo "admin 그룹 쓰기 권한 설정 중... (예: $not_shared)"
    sudo chgrp -R admin /opt/homebrew
    sudo chmod -R g+w /opt/homebrew
  else
    echo "권한 정상: admin 그룹 쓰기 허용"
  fi
}
fix_permissions

# 업데이트가 중간에 실패해 Homebrew 코드가 서로 다른 버전으로 섞이면
# 모든 brew 명령이 Ruby 오류로 실패한다. 공식 복구 명령으로 정상 버전으로 되돌린다.
# (설치된 패키지는 건드리지 않는다)
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
BREW_REPO="$(brew --repository)"
if [ -n "$(git --no-optional-locks -C "$BREW_REPO" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  echo "Homebrew 코드가 일부만 갱신된 상태 → brew update-reset"
  brew update-reset "$BREW_REPO"
  # update-reset이 새로 쓴 파일도 그룹 쓰기 권한이 없으므로 다시 맞춘다.
  fix_permissions
fi

# 검증
if [ -n "$(find_not_shared)" ]; then
  echo "오류: 권한 설정 실패: $(find_not_shared)"
  exit 1
fi
if ! brew config >/dev/null 2>&1; then
  echo "오류: brew 명령이 여전히 실패합니다. 'brew config' 출력을 확인하세요."
  exit 1
fi
echo "완료: Homebrew 다중 사용자 공유 설정됨"
echo "  - /opt/homebrew → admin 그룹 쓰기 허용"
echo "  - admin 그룹에 속한 모든 사용자가 brew 사용 가능"
echo "※ 다른 계정에서 brew를 사용한 뒤 이 계정에서 brew 오류가 나면 이 스크립트를 다시 실행"
