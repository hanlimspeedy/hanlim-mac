# Mac 초기 설정 스크립트

## 구조

```
mac-setup/
├── README.md
├── config/
│   ├── karabiner.json               # Karabiner-Elements 설정 (윈도우 스타일)
│   ├── KARABINER.md                 # Karabiner 설정 가이드 + 트러블슈팅
│   ├── TERMIUS.md                   # Termius 설정 가이드 (기본 터미널)
│   ├── VNC.md                       # Windows에서 Mac VNC 접속 가이드
│   ├── 8BITDO.md                    # 8BitDo Zero 2 설정 가이드 (페이지 넘기기)
│   └── tmux.conf                    # tmux 설정 (mouse + Compose Bar)
├── 0100_xcode-cli-tools.sh          # Xcode CLI Tools (git 포함)
├── 0110_homebrew-shared.sh          # Homebrew 다중 사용자 공유 (admin 그룹, 멱등성 보장)
├── 0200_sudo-touchid.sh             # NOPASSWD sudoers + Touch ID 보존 (영구 비밀번호 없이 sudo)
├── 0210_ssh-remote-login.sh          # SSH 원격 로그인 켜기/끄기 + 실제 인증 테스트
├── 0211_ssh-remote-login-test.sh     # SSH 설정/포트/핸드셰이크/공개키 인증 검사
├── 0212_ssh-client-key.sh             # Desktop에 SSH 접속 키 생성 + 공개키 등록
├── 0215_vnc-server.sh                # macOS 내장 VNC 서버 (Windows TigerVNC 접속)
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
├── 1305_rdp-connect.sh             # Windows RDP 원격 데스크톱 연결 (소리는 Windows PC에서 재생)
├── 1310_cyberduck.sh               # Cyberduck FTP/SFTP/WebDAV/S3 GUI 클라이언트
├── 1340_home-samba-link.sh        # /home autofs 해제 + samba 링크 + Finder 디스크/즐겨찾기
├── 1360_rustdesk.sh               # RustDesk 원격 데스크톱 설치
├── 1365_rustdesk-autostart.sh     # RustDesk 부팅/로그인 자동 실행
├── 1396_reset-codex-claude-env.sh # CODEX_HOME/CLAUDE_CONFIG_DIR launchd 해제 (sudo)
├── 1400_claude-compose-bar.sh     # Claude Code Compose Bar (한글 입력 해결)
├── 1430_claude-reset-reinstall.sh # Claude Code/Desktop 완전 초기화 + 재설치 (dry-run 기본)
├── 1500_termius.sh                # Termius SSH 클라이언트
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
./0210_ssh-remote-login.sh  # SSH 원격 로그인
./0215_vnc-server.sh        # macOS 내장 VNC 서버 (Windows에서 접속)
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
./1300_smb-connect.sh              # Windows SMB 공유 폴더 연결
./1305_rdp-connect.sh              # Windows RDP 원격 데스크톱 연결 (소리는 Windows PC에서 재생)
./1310_cyberduck.sh                # Cyberduck FTP/SFTP 클라이언트
./1340_home-samba-link.sh          # /home autofs 해제 + samba 링크 + Finder 디스크/즐겨찾기 (1300 후 실행)
./1360_rustdesk.sh                 # RustDesk 원격 데스크톱 설치
./1365_rustdesk-autostart.sh on    # RustDesk 부팅/로그인 자동 실행
./1400_claude-compose-bar.sh       # Claude Code Compose Bar (한글 입력)
./1430_claude-reset-reinstall.sh   # Claude Code/Desktop 초기화 후보 확인 (dry-run 기본)
./1500_termius.sh                  # Termius SSH 클라이언트
./1600_vscode.sh                   # Visual Studio Code 설치
./1610_vscode-bold-font.sh         # VS Code 굵은 폰트 설정
./1700_kakaotalk.sh                # KakaoTalk
./1800_telegram.sh                 # Telegram
./1900_8bitdo-pageflip.sh          # 8BitDo Zero 2 페이지 넘기기 (Swift CLI 빌드)
```

### Claude Code/Desktop 완전 초기화 테스트 절차

`1430_claude-reset-reinstall.sh` 는 반복 가능성을 위해 단계별 실행을 지원한다.
테스트 중에는 `--step all` 또는 옵션 없는 전체 실행을 사용하지 말고, 아래 순서대로 한 단계씩 실행한다.

```bash
./1430_claude-reset-reinstall.sh --dry-run --step inventory
./1430_claude-reset-reinstall.sh --execute --step stop
./1430_claude-reset-reinstall.sh --execute --step uninstall-packages
./1430_claude-reset-reinstall.sh --execute --step delete-apps
./1430_claude-reset-reinstall.sh --execute --step delete-user-data
./1430_claude-reset-reinstall.sh --execute --step delete-system
./1430_claude-reset-reinstall.sh --execute --step delete-keychain
./1430_claude-reset-reinstall.sh --execute --step reset-tcc
./1430_claude-reset-reinstall.sh --execute --step project-local --include-project-local
./1430_claude-reset-reinstall.sh --execute --step install-desktop
./1430_claude-reset-reinstall.sh --execute --step install-code
./1430_claude-reset-reinstall.sh --execute --step verify
./1430_claude-reset-reinstall.sh --execute --step verify-clean
```

삭제 단계는 `rm -rfv` 또는 `sudo rm -rfv` 로 삭제되는 파일을 출력한다.
Claude 앱 번들은 `Info.plist` bundle id 를 확인한 뒤에만 삭제한다.
Claude Code 설정 백업인 `~/.claude.json.backup` 과 `~/.claude.json.backup.*` 도 사용자 데이터 삭제 단계에서 제거한다.
프로젝트 로컬 `.claude` 삭제는 후보를 개별 확인한다.
프로젝트 로컬 `.mcp.json` 은 파일 내용에 `claude` 또는 `anthropic` 이 들어간 경우만 후보로 올리며, `~/.codex` 내부는 삭제 후보에서 제외한다.
Claude Desktop 직접 다운로드가 Cloudflare challenge 등으로 실패하면 스크립트는 Homebrew 공식 cask `claude` 를 `--appdir="$HOME/Applications"` 로 설치한다.
스크립트는 단계 실행 중 Homebrew가 암묵적으로 auto-update 하지 않도록 `HOMEBREW_NO_AUTO_UPDATE=1` 을 기본 적용한다.
`verify-clean` 단계는 `/Applications/Claude.app`, Desktop 데이터, Claude Code 백업, VS Code 확장 캐시, Keychain 항목, 프로젝트 로컬 후보가 남았는지 확인한다.

### 재부팅 후

별도 작업 불필요. `0200_sudo-touchid.sh` 가 NOPASSWD 를 영구 적용해 두므로
부팅 직후부터 비밀번호/Touch ID 입력 없이 sudo 사용 가능.

## Karabiner-Elements

상세 설정 가이드, 트러블슈팅, 참고 자료는 [config/KARABINER.md](config/KARABINER.md) 참조.

### 다른 사용자 계정

Karabiner 앱/드라이버는 시스템 전체에 설치되지만, Karabiner 설정과 macOS 입력
소스 단축키 설정은 사용자별이다. 다른 macOS 사용자 계정에는 자동 적용되지
않으므로, 해당 계정으로 로그인한 뒤 아래를 실행한다.

```bash
cd /Users/Shared/root/hanlim-mac
./0400_input-switch-shift-space.sh
```

최초 실행 후에는 그 사용자 세션에서 Karabiner 손쉬운 사용, 입력 모니터링,
백그라운드 항목, 드라이버 확장 프로그램 권한을 확인해야 할 수 있다.

## 8BitDo Zero 2 (페이지 넘기기)

8BitDo Zero 2를 macOS 게임패드 모드(A+Start)로 연결, Swift CLI 도구
(`8bitdo-pageflip/main.swift`)로 게임패드 버튼을 Page Up/Down/방향키로 매핑.
키보드 모드(R+Start)는 입력 씹힘 문제로 사용 안 함. Karabiner는 8bitdo에 사용하지 않음.
상세 설정은 [config/8BITDO.md](config/8BITDO.md) 참조.

## Termius (기본 터미널)

macOS 기본 터미널 대신 Termius를 기본으로 사용. Ctrl+C/V 복사/붙여넣기, SSH, Local Terminal 지원.
상세 설정은 [config/TERMIUS.md](config/TERMIUS.md) 참조.

## Windows에서 Mac VNC 접속

`0215_vnc-server.sh`로 macOS 내장 VNC 서버를 켜고 Windows의 TigerVNC
Viewer에서 접속한다. 외부망에서는 TCP 5900을 포트 포워딩하지 말고
Tailscale IP를 사용한다.

```bash
./0215_vnc-server.sh          # 켜기
./0215_vnc-server.sh on --password-file .vnc-passwd.env
./0215_vnc-server.sh status   # 상태 및 접속 주소
./0215_vnc-server.sh off      # 끄기
```

상세 설정과 macOS 최초 보안 승인, Windows 접속 및 문제 해결은
[config/VNC.md](config/VNC.md) 참조.

## RustDesk

Homebrew로 RustDesk를 설치하고, macOS 부팅 및 로그인 화면/Aqua 세션에서
자동 실행되도록 launchd daemon과 agent를 등록한다.

```bash
./1360_rustdesk.sh
./1365_rustdesk-autostart.sh on
./1365_rustdesk-autostart.sh status
./1365_rustdesk-autostart.sh off
```

최초 한 번 `시스템 설정 → 개인정보 보호 및 보안`에서 RustDesk의
`화면 및 시스템 오디오 녹음`, `손쉬운 사용`, 필요 시 `입력 모니터링`
권한을 허용해야 화면 보기와 원격 제어가 정상 동작한다.

## Mac SSH 원격 로그인

`0210_ssh-remote-login.sh`는 macOS 원격 로그인을 켜고 현재 사용자의 SSH
접근 권한, `sshd` 설정, TCP 22 및 실제 공개키 인증을 확인한다. 테스트에는
일회용 키를 사용하며 종료 시 `~/.ssh/authorized_keys`를 원래 상태로 복구한다.

```bash
./0210_ssh-remote-login.sh             # 켜기 + 실제 인증 테스트
./0210_ssh-remote-login.sh on --allow-any-host # iam의 원본 IP 제한 제거
./0210_ssh-remote-login.sh status      # 설정과 포트 상태
./0211_ssh-remote-login-test.sh        # 테스트만 다시 실행
./0211_ssh-remote-login-test.sh --no-auth  # 파일 변경 없는 핸드셰이크 검사
./0212_ssh-client-key.sh                # Desktop에 전용 키 생성 + 등록
./0210_ssh-remote-login.sh off         # 끄기
```

기본 테스트 대상은 기본 네트워크 인터페이스의 LAN IP다. 공유기에서 TCP 22를
인터넷에 직접 노출하지 말고 외부 접속에는 Tailscale 같은 VPN을 사용한다.
`sshd_config`에 `AllowUsers` 원본 IP 제한이 있으면 LAN과 VPN의 결과가 다를 수
있으므로 `./0211_ssh-remote-login-test.sh --host 접속주소`로 각각 검사한다.
`--allow-any-host`는 `AllowUsers iam`을 적용해 macOS 계정은 제한하면서 LAN,
Tailscale 등 접속 원본 IP 제한만 제거한다. 이전 규칙은 최초 실행 시
`/var/backups/hanlim-mac`에 백업한다.

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
