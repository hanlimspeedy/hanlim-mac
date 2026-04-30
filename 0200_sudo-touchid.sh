#!/bin/bash
set -e

echo "==> Touch ID sudo + 공유 세션 + 로그아웃까지 유지"

# Homebrew 환경 로드 (pam-reattach 설치용)
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# pam-reattach: tmux/screen 안에서도 Touch ID 프롬프트 동작하도록
if ! brew list pam-reattach &>/dev/null; then
  echo "pam-reattach 설치 중..."
  brew install pam-reattach
fi

PAM_REATTACH="$(brew --prefix)/lib/pam/pam_reattach.so"

# /etc/sudoers.d/timeout: 임시파일에 작성 후 visudo로 문법 검증, 통과 시 설치
# - timestamp_timeout=-1: 캐시 영구 유지
# - !tty_tickets: 모든 터미널 캐시 공유
# - <user> NOPASSWD ALL: 부팅 직후부터 비밀번호 없이 sudo (단일 사용자 Mac 전제)
USER_NAME="$(whoami)"
TMP_SUDOERS="$(mktemp)"
cat > "$TMP_SUDOERS" <<EOF
Defaults timestamp_timeout=-1
Defaults !tty_tickets
${USER_NAME} ALL=(ALL) NOPASSWD: ALL
EOF

if ! sudo visudo -cf "$TMP_SUDOERS" >/dev/null; then
  echo "오류: sudoers 문법 검증 실패"
  rm -f "$TMP_SUDOERS"
  exit 1
fi

sudo install -o root -g wheel -m 440 "$TMP_SUDOERS" /etc/sudoers.d/timeout
rm -f "$TMP_SUDOERS"

# /etc/pam.d/sudo_local: pam_reattach (tmux 호환) + pam_tid (Touch ID)
sudo tee /etc/pam.d/sudo_local >/dev/null <<EOF
auth       optional       ${PAM_REATTACH}
auth       sufficient     pam_tid.so
EOF
sudo chown root:wheel /etc/pam.d/sudo_local
sudo chmod 644 /etc/pam.d/sudo_local

# NOPASSWD 적용 후 검증: 캐시 무효화해도 sudo 가 통과해야 함
sudo -K
if ! sudo -n true 2>/dev/null; then
  echo "오류: NOPASSWD 적용 실패 (sudo -n true 가 만료 상태에서 거절됨)"
  exit 1
fi

if ! bash -c 'sudo -n true' 2>/dev/null; then
  echo "오류: 자식 셸에서 sudo 미작동"
  exit 1
fi

echo "완료: 비밀번호 없이 sudo 가능 (NOPASSWD)"
echo "  - ${USER_NAME} 계정은 sudo 시 비밀번호/Touch ID 요구 안 함"
echo "  - Touch ID: pam_tid + pam_reattach 도 보존 (필요 시 NOPASSWD 라인 제거하면 복귀)"
echo "  - 캐시 설정도 보존: timestamp_timeout=-1, !tty_tickets"
