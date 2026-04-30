# Mac 초기 설정 스크립트

## 구조

```
mac-setup/
├── README.md
├── config/
│   ├── karabiner.json               # Karabiner-Elements 설정 (윈도우 스타일)
│   ├── KARABINER.md                 # Karabiner 설정 가이드 + 트러블슈팅
│   ├── TERMIUS.md                   # Termius 설정 가이드 (기본 터미널)
│   ├── 8BITDO.md                    # 8BitDo Zero 2 설정 가이드 (페이지 넘기기)
│   └── tmux.conf                    # tmux 설정 (mouse + Compose Bar)
├── 0100_xcode-cli-tools.sh          # Xcode CLI Tools (git 포함)
├── 0110_homebrew-shared.sh          # Homebrew 다중 사용자 공유 (admin 그룹, 멱등성 보장)
├── 0200_sudo-touchid.sh             # NOPASSWD sudoers + Touch ID 보존 (영구 비밀번호 없이 sudo)
├── 0220_claude-screencapture.sh     # Claude Code 화면 캡쳐 권한 설정 (최초 1회)
├── 0300_homebrew.sh                 # Homebrew 설치
├── 0400_input-switch-shift-space.sh # Karabiner + Shift+Space 한영전환 + Ctrl↔Cmd
├── 0600_microsoft-office.sh        # Microsoft 365 Office 설치
├── 0700_bettershot.sh              # Better Shot 스크린샷 캡처 + 편집 도구 (무료, 오픈소스)
├── 0800_iina.sh                    # IINA 동영상 플레이어
├── 0900_keka.sh                    # Keka 압축 해제/생성 (RAR, 7z, TGZ 등)
├── 1000_mouse-no-acceleration.sh   # 마우스 가속 끄기 (윈도우 스타일)
├── 1010_scroll-no-smooth.sh       # 스크롤 애니메이션 비활성화 (윈도우 스타일)
├── 1100_startup-mute.sh            # 부팅 사운드 끄기
├── 1200_menubar-volume.sh          # 메뉴바 볼륨 아이콘 표시
├── 1300_smb-connect.sh             # Windows SMB 공유 폴더 연결
├── 1310_cyberduck.sh               # Cyberduck FTP/SFTP/WebDAV/S3 GUI 클라이언트
├── 1400_claude-compose-bar.sh     # Claude Code Compose Bar (한글 입력 해결)
├── 1500_termius.sh                # Termius SSH 클라이언트
├── 1550_ghostty.sh                # Ghostty 터미널 (Claude Code + tmux 최적화)
├── 1600_vscode.sh                 # Visual Studio Code 설치
├── 1610_vscode-bold-font.sh       # VS Code 굵은 폰트 설정 (Noto Sans KR Black)
├── 1700_kakaotalk.sh              # KakaoTalk (Mac App Store)
├── 1800_telegram.sh               # Telegram 메신저
├── 1900_8bitdo-pageflip.sh        # 8BitDo Zero 2 페이지 넘기기 (Swift CLI 빌드)
├── 8bitdo-pageflip/               # Swift CLI 소스 + 빌드 산출물
│   ├── main.swift                 # GameController + CGEvent 매핑
│   └── 8bitdo-pageflip            # 컴파일된 바이너리
├── CLAUDE_COMPOSE_BAR.md          # Compose Bar 상세 문서
├── .env                            # SMB 접속 정보 (git 제외)
└── .gitignore
```

## 사용법

### 최초 설치 (순서대로)

```bash
cd ~/mac-setup
./0100_xcode-cli-tools.sh   # Xcode CLI Tools 설치 (팝업 승인 필요)
./0110_homebrew-shared.sh   # Homebrew 다중 사용자 공유 (다른 계정이 brew 설치한 경우)
./0200_sudo-touchid.sh      # NOPASSWD sudoers + Touch ID 보존 (영구 비밀번호 없이 sudo)
./0220_claude-screencapture.sh  # 화면 캡쳐 권한 (최초 1회)
./0300_homebrew.sh           # Homebrew 설치
./0400_input-switch-shift-space.sh  # Karabiner + 한영전환 + 키보드 설정
./0600_microsoft-office.sh         # Microsoft 365 Office 설치
./0700_bettershot.sh               # Better Shot 스크린샷 캡처 + 편집 도구
./0800_iina.sh                     # IINA 동영상 플레이어
./0900_keka.sh                     # Keka 압축 해제/생성
./1000_mouse-no-acceleration.sh    # 마우스 가속 끄기 (로그아웃 후 적용)
./1010_scroll-no-smooth.sh         # 스크롤 애니메이션 비활성화
./1100_startup-mute.sh             # 부팅 사운드 끄기
./1200_menubar-volume.sh           # 메뉴바 볼륨 아이콘 표시
./1310_cyberduck.sh                # Cyberduck FTP/SFTP 클라이언트
./1400_claude-compose-bar.sh       # Claude Code Compose Bar (한글 입력)
./1500_termius.sh                  # Termius SSH 클라이언트
./1550_ghostty.sh                  # Ghostty 터미널 (로컬 Claude Code용)
./1600_vscode.sh                   # Visual Studio Code 설치
./1610_vscode-bold-font.sh         # VS Code 굵은 폰트 설정
./1700_kakaotalk.sh                # KakaoTalk
./1800_telegram.sh                 # Telegram
./1900_8bitdo-pageflip.sh          # 8BitDo Zero 2 페이지 넘기기 (Swift CLI 빌드)
```

### 재부팅 후

별도 작업 불필요. `0200_sudo-touchid.sh` 가 NOPASSWD 를 영구 적용해 두므로
부팅 직후부터 비밀번호/Touch ID 입력 없이 sudo 사용 가능.

## Karabiner-Elements

상세 설정 가이드, 트러블슈팅, 참고 자료는 [config/KARABINER.md](config/KARABINER.md) 참조.

## 8BitDo Zero 2 (페이지 넘기기)

8BitDo Zero 2를 macOS 게임패드 모드(A+Start)로 연결, Swift CLI 도구
(`8bitdo-pageflip/main.swift`)로 게임패드 버튼을 Page Up/Down/방향키로 매핑.
키보드 모드(R+Start)는 입력 씹힘 문제로 사용 안 함. Karabiner는 8bitdo에 사용하지 않음.
상세 설정은 [config/8BITDO.md](config/8BITDO.md) 참조.

## Termius (기본 터미널)

macOS 기본 터미널 대신 Termius를 기본으로 사용. Ctrl+C/V 복사/붙여넣기, SSH, Local Terminal 지원.
상세 설정은 [config/TERMIUS.md](config/TERMIUS.md) 참조.

## Claude Code 연동 설명

### 비밀번호 없이 sudo (NOPASSWD)
- Claude Code 의 Bash 도구는 TTY 가 없어 비밀번호/Touch ID 입력 불가 → 인증 자체를 우회해야 함
- `0200_sudo-touchid.sh` 가 `/etc/sudoers.d/timeout` 에 `<user> ALL=(ALL) NOPASSWD: ALL` 추가
- 부팅 직후부터 모든 터미널/Claude Code 에서 sudo 즉시 통과
- `timestamp_timeout=-1`, `!tty_tickets` 도 함께 적용 (NOPASSWD 라인 제거 시 Touch ID 캐시 모드로 복귀)
- Touch ID PAM(`pam_tid` + `pam_reattach`) 도 보존: NOPASSWD 비활성화하면 일반 터미널 `sudo` 는 Touch ID 로 동작

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

## 배터리 충전 제한
- macOS 26.4 (Tahoe)부터 시스템 설정 > 배터리 > 충전 한도 80% native 지원
- 별도 스크립트/서드파티 도구 불필요

## 기본 브라우저
- Chrome 기본 브라우저 설정: `brew install defaultbrowser && defaultbrowser chrome`

## 네이밍 규칙
- 4자리 번호 (0100, 0200, ...)
- 100 간격으로 중간 삽입 가능 (예: 0150, 0250)
- 파일명 영문만 사용
