# Windows에서 Mac VNC 접속

`0215_vnc-server.sh`는 별도 서버 프로그램 대신 macOS에 포함된
Remote Management/AppleVNCServer를 설정한다. Windows에서는 무료 오픈소스
TigerVNC Viewer로 접속한다.

## 빠른 설정

Mac에서 실행:

```bash
cd /Users/Shared/root/hanlim-mac
./0215_vnc-server.sh
```

스크립트가 다음 작업을 수행한다.

- macOS 화면 공유 서비스 활성화
- 현재 macOS 사용자에게 화면 보기 및 제어 권한 부여
- 원격 관리 접근 범위를 지정 사용자로 제한
- Windows용 표준 VNC 암호 인증 활성화
- TCP 5900 접속 주소 출력

다른 계정을 허용하려면 다음과 같이 실행한다.

```bash
./0215_vnc-server.sh on --user macOS계정
```

권한이 `600`인 암호 파일을 사용하는 자동 실행:

```bash
chmod 600 .vnc-passwd.env
./0215_vnc-server.sh on --password-file .vnc-passwd.env
```

파일은 암호 원문 한 줄 또는 `VNC_PASSWORD=암호` 형식을 지원한다. 셸 코드로
`source`하지 않으므로 파일 안의 다른 문자열이 명령으로 실행되지 않는다.

상태 확인과 비활성화:

```bash
./0215_vnc-server.sh status
./0215_vnc-server.sh off
```

`off`는 VNC 암호 접속과 화면 공유 서비스를 비활성화하지만 기존 암호 파일과
사용자 권한 설정은 삭제하지 않는다. 다시 `on`을 실행하면 새 VNC 암호를
입력하게 된다.

macOS Tahoe에서 Apple `kickstart`가 활성화 표시 파일을 만들지 못하고
중단되는 경우가 있다. 스크립트는 화면 공유 서비스가 실제로 로드됐는지
확인한 뒤 암호와 제어 권한 구성을 별도 단계로 계속한다.

## VNC 암호 제한

macOS의 타사 VNC 호환 암호는 처음 8바이트만 사용한다. 스크립트는 공백 없는
ASCII 문자 6~8개를 허용하며 8자를 권장한다.

스크립트와 저장소에는 평문 암호를 저장하지 않고, 셸 명령행 인자로도
노출하지 않는다. 입력값을 표준 입력으로 관리자 프로세스에 전달하고,
Apple `kickstart`가 지원하는 환경변수를 통해 설정한다. macOS는 암호를
아래 root 전용 파일에 변환하여 저장한다.

```text
/Library/Preferences/com.apple.VNCSettings.txt
```

이 규격은 긴 암호를 사용할 수 없으므로 VNC 포트를 인터넷에 직접 노출하면
안 된다.

## Windows 설정

1. [TigerVNC 공식 릴리스](https://github.com/TigerVNC/tigervnc/releases)에서
   Windows용 Viewer를 설치한다.
2. `TigerVNC Viewer`를 실행한다.
3. `VNC server` 칸에 스크립트가 출력한 주소를 입력한다.
4. Mac에서 설정한 8자리 VNC 암호를 입력한다.

같은 공유기 안에서는 다음 중 하나를 사용한다.

```text
Mac의 LAN IP
Mac이름.local
```

TigerVNC는 기본 포트 5900을 사용하므로 보통 IP 주소만 입력하면 된다.
포트를 직접 지정해야 할 때 TigerVNC 문법은 `주소::5900`처럼 콜론 두 개를
사용한다.

## 외부 네트워크에서 접속

공유기에서 TCP 5900 포트 포워딩을 설정하지 않는다. Mac과 Windows 양쪽에
Tailscale을 설치하고 같은 tailnet에 로그인한 뒤, TigerVNC Viewer에 Mac의
Tailscale IP(`100.x.x.x`) 또는 MagicDNS 이름을 입력한다.

Mac의 Tailscale 설치:

```bash
./1350_tailscale.sh
open -a Tailscale
```

Windows용 설치 파일은 [Tailscale 다운로드 페이지](https://tailscale.com/download)
에서 받을 수 있다.

## 최초 한 번 확인할 macOS 설정

macOS 10.14 이후에는 명령줄에서 Remote Management를 활성화했을 때
화면은 보이지만 마우스와 키보드 제어가 제한될 수 있다. 이는 TCC 보안 정책이라
일반 스크립트가 강제로 승인할 수 없다.

제어가 되지 않으면 Mac에서 다음을 한 번 수행한다.

1. `시스템 설정 → 일반 → 공유`를 연다.
2. `원격 관리`를 한 번 껐다가 다시 켠다.
3. 정보 버튼을 눌러 허용 사용자와 제어 권한을 확인한다.
4. 스크립트를 다시 실행하여 VNC 암호 접속을 설정한다.

Apple 안내:

- [Mac 화면 공유 켜거나 끄기](https://support.apple.com/ko-kr/guide/mac-help/mh11848/mac)
- [Remote Management 활성화](https://support.apple.com/guide/remote-desktop/enable-remote-management-apd8b1c65bd/mac)

## 연결 확인

Mac:

```bash
./0215_vnc-server.sh status
```

Windows PowerShell:

```powershell
Test-NetConnection MAC_IP -Port 5900
```

`TcpTestSucceeded : True`가 표시되면 네트워크에서 VNC 포트까지 연결된다.

## 문제 해결

### 화면만 보이고 조작되지 않음

위의 `최초 한 번 확인할 macOS 설정`에 따라 원격 관리를 GUI에서 다시
활성화한다. 허용 계정에 `제어` 권한이 있는지도 확인한다.

### Windows에서 접속 자체가 안 됨

- Mac에서 `./0215_vnc-server.sh status` 실행
- 두 기기가 같은 LAN 또는 Tailscale tailnet에 있는지 확인
- Windows에서 `Test-NetConnection`으로 TCP 5900 확인
- Mac이 잠자기 상태인지 확인
- TigerVNC에 `vnc://`를 붙이지 말고 IP 주소만 입력

### 재부팅 후 원격 접속이 안 됨

FileVault가 켜진 Mac은 완전히 재부팅한 직후 디스크 잠금 해제를 위해 로컬
로그인이 필요할 수 있다. MacBook은 덮개를 닫으면 잠자기에 들어가 VNC와
Tailscale에 접속할 수 없다.

데스크톱 Mac은 `시스템 설정 → 에너지 → 네트워크 연결 시 깨우기`를 확인한다.
MacBook은 `시스템 설정 → 배터리 → 옵션 → 네트워크 연결 시 깨우기`를
확인한다.

### RealVNC Viewer 사용

현재 RealVNC Viewer는 타사 VNC 서버에 연결할 때 유료 플랜을 요구할 수 있다.
macOS 내장 서버에는 계정이 필요 없는 TigerVNC Viewer를 권장한다.
