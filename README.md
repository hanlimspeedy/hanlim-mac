# Mac 초기 설정 스크립트

## 구조

```
mac-setup/
├── README.md
├── 0100_xcode-cli-tools.sh          # Xcode CLI Tools (git 포함)
├── 0200_sudo-touchid.sh             # Touch ID sudo + 공유 세션 (최초 1회)
├── 0210_claude-sudo-activate.sh     # 재부팅 후 Claude Code sudo 활성화
├── 0220_claude-screencapture.sh     # Claude Code 화면 캡쳐 권한 설정 (최초 1회)
├── 0300_homebrew.sh                 # Homebrew 설치
└── 0400_input-switch-shift-space.sh # Shift+Space 한영전환
```

## 사용법

### 최초 설치 (순서대로)

```bash
cd ~/mac-setup
./0100_xcode-cli-tools.sh   # Xcode CLI Tools 설치 (팝업 승인 필요)
./0200_sudo-touchid.sh      # Touch ID sudo 설정 (최초 1회)
./0220_claude-screencapture.sh  # 화면 캡쳐 권한 (최초 1회)
./0300_homebrew.sh           # Homebrew 설치
./0400_input-switch-shift-space.sh  # 한영전환 설정
```

### 재부팅 후 (매번)

```bash
~/mac-setup/0210_claude-sudo-activate.sh
```

이것만 실행하면 Claude Code에서 sudo 사용 가능.

## Claude Code 연동 설명

### sudo 공유 세션 (`!tty_tickets`)
- Claude Code의 Bash 도구는 TTY가 없어서 비밀번호 입력 불가
- `!tty_tickets` 설정으로 모든 터미널이 sudo 인증 공유
- 다른 터미널에서 `sudo -v` 한 번 실행하면 Claude Code에서도 sudo 사용 가능
- `timestamp_timeout=-1`: 로그아웃/재부팅 전까지 유지

### 화면 캡쳐
- Claude Code에서 `screencapture` 명령으로 현재 화면 확인 가능
- 시스템 설정 > 개인정보 보호 및 보안 > 화면 녹화 에서 Terminal 권한 허용 필요
- 한 번 설정하면 재부팅 후에도 유지

## GitHub 연동

### 저장소
- https://github.com/hanlimspeedy/hanlim-mac

### 최초 설정 (이미 완료된 항목)
1. `brew install gh` (GitHub CLI 설치)
2. `gh auth login -p https -w` (브라우저 인증)
3. `gh auth setup-git` (git credential helper 연동)

### 변경사항 push
```bash
cd ~/mac-setup
git add -A
git commit -m "메시지"
git push
```

### 다른 맥에서 복원
```bash
gh auth login -p https -w
git clone https://github.com/hanlimspeedy/hanlim-mac.git ~/mac-setup
cd ~/mac-setup
# 순서대로 스크립트 실행
```

## 기본 브라우저
- Chrome 기본 브라우저 설정: `brew install defaultbrowser && defaultbrowser chrome`

## 네이밍 규칙
- 4자리 번호 (0100, 0200, ...)
- 100 간격으로 중간 삽입 가능 (예: 0150, 0250)
- 파일명 영문만 사용
