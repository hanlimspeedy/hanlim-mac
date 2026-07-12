# Karabiner-Elements 설정 가이드

## 현재 설정 요약

| 기능 | 방식 | 상태 |
|------|------|------|
| 윈도우 스타일 단축키 (13개) | complex_modifications | 완료 |
| Num Lock 숫자패드 탐색키 | complex_modifications + variable toggle | 완료 |
| Shift+Space 한영전환 | complex_modifications + Caps Lock | 완료 |
| 2.4G 외장 키보드 Ctrl↔Cmd | device simple_modifications | 완료 |

## 적용 범위

Karabiner 앱/드라이버는 시스템 전체에 설치되지만, 아래 항목은 사용자별이다.

- `~/.config/karabiner/karabiner.json`
- `com.apple.symbolichotkeys`
- `com.apple.HIToolbox`

다른 macOS 사용자 계정에는 자동 적용되지 않는다. 각 사용자로 로그인한 뒤
`/Users/Shared/root/hanlim-mac/0400_input-switch-shift-space.sh`를 실행해야 한다.
최초 실행 후에는 해당 사용자 세션에서 Karabiner 입력 모니터링/접근성 권한을
허용하고, 백그라운드 항목과 드라이버 확장 프로그램이 켜져 있는지 확인해야
할 수 있다.

## 적용된 단축키 목록

### 2.4G 외장 키보드

B.O.W HD315 2.4G 리시버는 아래 HID로 잡힌다.

- Vendor ID: `0x25a7` / `9639`
- Product ID: `0xfa61` / `64097`
- Product: `2.4G Receiver`

이 장치에만 `left_option`↔`left_command`, `right_option`↔`right_command`
스왑을 적용한다. 블루투스 연결은 다른 HID로 잡히며 Mac 레이아웃을 쓰므로
이 매핑 대상이 아니다.

확인:

```sh
hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'
```

| 윈도우 단축키 | macOS 동작 | 비고 |
|--------------|-----------|------|
| Shift+Space | 한영전환 | |
| Alt+F4 | 앱 종료 | |
| Home/End | 줄 처음/끝 | |
| Shift+Home/End | 선택하며 줄 처음/끝 | |
| Ctrl+Home/End | 문서 처음/끝 | |
| F5 | 새로고침 | |
| Ctrl+Shift+Esc | 활성 상태 보기 | |
| Ctrl+Insert | 복사 | |
| Shift+Insert | 붙여넣기 | |

### 삭제한 단축키 (vi/터미널 충돌)

아래 매핑은 vi/vim, tmux, 터미널에서 Ctrl 키와 충돌하여 제거함.

- Ctrl+C/V/X (복사/붙여넣기/잘라내기) — vi: Ctrl+C 인터럽트, Ctrl+V 비주얼블록
- Ctrl+Z (실행취소) — 터미널: 프로세스 중지
- Ctrl+Y (다시실행) — vi: 스크롤
- Ctrl+A (전체선택) — vi: 숫자 증가, tmux: 접두키
- Ctrl+S (저장) — 터미널: XOFF 정지
- Ctrl+N (새문서) — vi: 자동완성
- Ctrl+F (찾기) — vi: 페이지 다운
- Ctrl+B (굵게) — vi: 페이지 업
- Ctrl+W (닫기) — vi: 창 분할 접두키
- Ctrl+T (새탭) — vi: 태그 스택 복귀
- Ctrl+I (기울임) — vi: 점프리스트
- Ctrl+L (URL 이동) — 터미널: 화면 재그리기
- Ctrl+R (새로고침) — vi: redo, bash: 역검색
- Ctrl+Tab (앱 전환) — macOS 기본 동작 충돌
- Ctrl+↑/↓ (커서 이동) — macOS: Mission Control/App Exposé
- Ctrl+←/→ (단어 이동) — macOS: 데스크탑 전환
- Ctrl+Esc (Launchpad) — 거의 사용 안 함
- Ctrl+Click (다중선택) — macOS 우클릭과 혼동
- Cmd+L (로그아웃) — 앱별 Cmd+L 충돌
- Cmd+Tab (Mission Control) — macOS 기본 앱 전환 충돌
- Backspace/Delete (Finder) — Finder 이름 변경 시 충돌

### Num Lock 숫자패드 탐색키

macOS는 Num Lock을 지원하지 않아 숫자패드가 항상 숫자만 전송됨.
Karabiner 변수(`num_lock_off`) 토글로 윈도우와 동일한 Num Lock 동작 구현.

- Num Lock 키를 누르면 토글 (숫자 ↔ 탐색)
- Num Lock OFF: keypad_0→Insert, keypad_7→Home, keypad_1→End, keypad_9→PgUp, keypad_3→PgDn 등
- Shift+keypad_0 → Cmd+V (붙여넣기), Ctrl+keypad_0 → Cmd+C (복사) 직접 매핑

## Shift+Space 한영전환

### 결론

이 저장소의 정답은 `Shift+Space → caps_lock`이다.

왼쪽 Caps Lock 키가 macOS에서 ABC↔두벌식 전환으로 정상 동작한다면,
Karabiner는 `Shift+Space`를 같은 `caps_lock` 키 입력으로 보내는 역할만 해야
한다. 이 경로가 macOS 네이티브 한영전환을 타기 때문에 메뉴바 표시와 현재 앱의
실제 입력 컨텍스트가 함께 바뀐다.

### 방식
Karabiner에서 `Shift+Space`를 `caps_lock` 키 입력으로 변환한다.
macOS의 Caps Lock 한영전환이 실제 입력 컨텍스트까지 갱신하므로, 메뉴바만
한글로 바뀌고 실제 입력은 영어로 남는 문제를 피한다.

또한 앱/문서별 입력 소스 자동 전환(`TextInputGlobalPropertyPerContextInput`)을
끈다. 이 옵션이 켜져 있으면 메뉴바 표시는 바뀌었는데 현재 터미널 입력
컨텍스트는 이전 입력 소스를 유지하는 식의 불일치가 생길 수 있다.

Caps Lock의 길게 누르기 대문자 고정은 끈다
(`AppleCapsLockPressAndHoldToggleOff=true`). 이 기능이 켜져 있으면 macOS가
Caps Lock을 짧게 누른 한영전환인지 길게 누른 대문자 고정인지 판별해야 해서
한영전환 지연이나 씹힘이 생길 수 있다. 대문자는 Shift로 입력한다.

전제 조건: macOS 설정에서 왼쪽 Caps Lock 키가 ABC↔두벌식 전환으로 정상
동작해야 한다.

### 실패했던 방식

아래 방식은 다시 도입하지 않는다.

- `select_input_source`: Karabiner가 입력 소스를 직접 선택하는 방식이다. 한국어
  같은 CJK 입력 소스에서 메뉴바는 한글로 바뀌지만 현재 앱의 실제 입력
  컨텍스트가 영어로 남을 수 있다. 실제 증상은 "menubar에는 Hangul이 보이는데
  한글이 입력되지 않음"이다.
- `Ctrl+Option+Space`: macOS의 "Select next source in Input menu" 순환
  단축키다. 입력 메뉴에 ABC/두벌식 외의 항목이 있으면 한 번에 ABC↔두벌식으로
  가지 않을 수 있다.
- `Ctrl+Space`: macOS의 "Select the previous input source" 단축키다. 이론상
  토글에 가깝지만, Karabiner 가상 키보드가 보낸 이벤트가 현재 환경에서 안정적으로
  입력 소스 전환으로 처리되지 않았다.
- 별도 helper나 직접 TIS 전환: `select_input_source`와 같은 계열의 실패가 날 수
  있어 기본 경로로 쓰지 않는다.

### 검증 방법

1. 왼쪽 Caps Lock 키를 직접 눌러 ABC↔두벌식이 실제 입력까지 바뀌는지 확인한다.
2. `Shift+Space`를 눌렀을 때 왼쪽 Caps Lock과 같은 결과가 나와야 한다.
3. 메뉴바만 한글이고 실제 입력이 영어라면 `select_input_source` 계열로 회귀한
   것이므로 `config/karabiner.json`의 첫 규칙이 `key_code: caps_lock`인지 본다.
4. Caps Lock을 길게 눌러도 대문자 고정이 켜지지 않아야 한다.

### 입력 소스 ID
- 두벌식: `com.apple.inputmethod.Korean.2SetKorean`
- ABC: `com.apple.keylayout.ABC`

## 트러블슈팅

`~/.config/karabiner/karabiner.json`이 맞는데 모든 Karabiner 설정이 동작하지
않으면 설정 파일보다 Core Service 권한/연결 상태를 먼저 확인한다.

### macOS 권한 점검 체크리스트

Karabiner-Elements 공식 문서의 필수 macOS 설정은 아래 네 가지다.

1. 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 앱 백그라운드 활동
   - `Karabiner-Elements Non-Privileged Agents v2`: 켬
   - `Karabiner-Elements Privileged Daemons v2`: 켬
2. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용
   - `Karabiner-Core-Service`: 켬
3. 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 확장 프로그램 > 드라이버 확장
   - `.Karabiner-VirtualHIDDevice-Manager`: 켬
4. 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링
   - `Karabiner-Core-Service`: 켬

Karabiner 16.0.0 이상에서는 입력 모니터링이 보통 손쉬운 사용 권한으로
대체되지만, 문제 진단 시에는 위 네 항목을 모두 확인한다. `Terminal` 입력
모니터링 권한은 Karabiner 키매핑의 필수 항목이 아니다.

CLI로 확인:

```sh
karabiner_cli --version
karabiner_cli --show-current-profile-name
karabiner_cli --list-connected-devices
karabiner_cli --lint-complex-modifications ~/.config/karabiner/karabiner.json
cat ~/.local/share/karabiner/tmp/core-service-permission-check-result.json
systemextensionsctl list | grep -i 'karabiner\|pqrs\|VirtualHID'
```

정상 예:

```text
Windows Style
~/.config/karabiner/karabiner.json: ok
{"accessibility_process_trusted":true,"iohid_listen_event_allowed":true}
org.pqrs.Karabiner-DriverKit-VirtualHIDDevice ... [activated enabled]
```

시스템 설정 화면을 직접 열기:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
```

### Core Service 연결 상태

```sh
karabiner_cli --list-connected-devices
```

`core_service_client connect_failed`가 나오면 Karabiner가 Core Service에
연결하지 못하는 상태다. 위 권한 네 항목을 확인한 뒤 Karabiner를 재시작하거나
재로그인한다.

Karabiner 구버전에서는 아래 state 파일에 `hid_device_open_permitted=false`가
남을 수 있다. 현재 버전에서 파일이 없으면 `core-service-permission-check-result.json`
과 시스템 설정 화면을 우선한다.

```sh
jq . "/Library/Application Support/org.pqrs/tmp/karabiner_core_service_state.json"
```

### 입력 모니터링 목록에 Core Service가 없을 때

실수 금지: `Karabiner-EventViewer`를 열면 안 된다. EventViewer는 키 입력
확인 도구이고, 켜져 있으면 Karabiner modifications를 임시로 비활성화할 수도
있다. 입력 모니터링 목록에 EventViewer만 보이면 문제 해결 경로가 아니다.

`Karabiner-Core-Service`를 입력 모니터링 목록에 추가하려면 Karabiner 설정 앱의
권한 안내 모드를 직접 연다.

```sh
pkill -x Karabiner-EventViewer 2>/dev/null || true
open -n -a "Karabiner-Elements" --args input-monitoring-macos26
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
```

그 뒤 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링에서
`Karabiner-Core-Service`를 켠다. 정상 상태에서는 같은 목록에
`Karabiner-Core-Service`와 `Karabiner-EventViewer`가 모두 보일 수 있지만,
필수 항목은 `Karabiner-Core-Service`다.

설치 스크립트는 이 상태를 진단하고 입력 모니터링 설정 화면을 연다.

### EventViewer 확인

Karabiner-EventViewer를 열어 아래 상태를 확인한다.

- Main: `Monitoring events` 켬
- Main: `Temporarily turns off all Karabiner-Elements modifications` 끔
- Settings 또는 System Extensions: `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`가 `[activated enabled]`

EventViewer는 키 입력 확인 도구다. 열려 있어도 위 임시 비활성화 스위치가
꺼져 있으면 키매핑을 막지 않는다.

## 참고 자료

- Karabiner-Elements 공식 문서: https://karabiner-elements.pqrs.org/docs/
- macOS 필수 권한 설정: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/
- 커뮤니티 규칙 저장소: https://ke-complex-modifications.pqrs.org/
