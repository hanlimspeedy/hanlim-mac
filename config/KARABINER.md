# Karabiner-Elements 설정 가이드

## 현재 설정 요약

| 기능 | 방식 | 상태 |
|------|------|------|
| 윈도우 스타일 단축키 (35개) | complex_modifications | 완료 |
| Num Lock 숫자패드 탐색키 | complex_modifications + variable toggle | 완료 |
| Shift+Space 한영전환 | complex_modifications + select_input_source | 완료 |

## 윈도우 스타일 단축키 (complex_modifications)

Karabiner 공식 커뮤니티 규칙 `Windows shortcuts on macOS` 기반.
- **원본**: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/windows_shortcuts_on_macos.json

### 적용된 단축키 목록

| 윈도우 단축키 | macOS 동작 | 비고 |
|--------------|-----------|------|
| Ctrl+C/V/X | 복사/붙여넣기/잘라내기 | |
| Ctrl+Z | 실행취소 | |
| Ctrl+Y | 다시실행 (Cmd+Shift+Z) | |
| Ctrl+A | 전체선택 | |
| Ctrl+S | 저장 | |
| Ctrl+N | 새문서 | |
| Ctrl+W | 닫기 | |
| Ctrl+T | 새탭 | |
| Ctrl+B | 굵게 | |
| Ctrl+I | 기울임 | |
| Ctrl+L | URL 이동 | 브라우저만 |
| Ctrl+R | 새로고침 | 브라우저만 |
| F5 | 새로고침 | |
| Alt+F4 | 앱 종료 | |
| Home/End | 줄 처음/끝 | |
| Shift+Home/End | 선택하며 줄 처음/끝 | |
| Ctrl+Home/End | 문서 처음/끝 | |
| Ctrl+Esc | Launchpad | |
| Ctrl+Shift+Esc | 활성 상태 보기 | |
| F2 | 이름변경 | Finder만 |
| Enter | 열기 | Finder만 |
| Ctrl+Insert | 복사 | |
| Shift+Insert | 붙여넣기 | |
| Ctrl+클릭 | 다중선택 | |

### Num Lock 숫자패드 탐색키

macOS는 Num Lock을 지원하지 않아 숫자패드가 항상 숫자만 전송됨.
Karabiner 변수(`num_lock_off`) 토글로 윈도우와 동일한 Num Lock 동작 구현.

- Num Lock 키를 누르면 토글 (숫자 ↔ 탐색)
- Num Lock OFF: keypad_0→Insert, keypad_7→Home, keypad_1→End, keypad_9→PgUp, keypad_3→PgDn 등
- Shift+keypad_0 → Cmd+V (붙여넣기), Ctrl+keypad_0 → Cmd+C (복사) 직접 매핑
- Karabiner rules는 체이닝 안 되므로 modifier 조합은 직접 매핑 필요

### 터미널 제외 설정

원본 규칙은 Terminal, iTerm2 등 터미널 앱을 제외하지만, Termius 등에서 윈도우 스타일로 사용하기 위해 대부분의 터미널 제외를 해제함.

- **제외 유지**: macOS Terminal.app (`com.apple.Terminal`) — Ctrl+C = SIGINT 유지
- **제외 해제**: iTerm2, Hyper, Alacritty, kitty, WezTerm, Termius
- **주의**: Termius에서 프로세스 중단이 필요하면 Termius 자체 단축키 사용

## Shift+Space 한영전환

### 방식
`select_input_source`로 입력 소스를 직접 지정하여 전환.
- `input_source_if` 조건으로 현재 입력 소스 판별
- 영어(ABC) → 한국어(두벌식), 한국어 → 영어 각각 별도 규칙
- **원본**: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/ChangeInputSourceDirectlyForKorean.json

### 입력 소스 ID
- 두벌식: `com.apple.inputmethod.Korean.2SetKorean`
- ABC: `com.apple.keylayout.ABC`

### 입력 소스 ID 확인 방법
```bash
# 설치된 입력 소스 목록
defaults read com.apple.HIToolbox AppleEnabledInputSources
# 현재 활성 입력 소스
defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID
```

## 트러블슈팅 기록

### 1. Karabiner 데몬(Core-Service)이 안 뜨는 문제

**증상**: Karabiner 설치 후 키 매핑이 전혀 동작하지 않음. `Core-Service` exit code -9 (SIGKILL).

**원인**: macOS 보안 정책상 3가지 권한을 모두 수동으로 허용해야 함.

**해결**: 아래 3가지 권한 허용 후 **재부팅** 필수.
1. 입력 모니터링: 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링 > `Karabiner-Core-Service` ON
2. 로그인 항목: 시스템 설정 > 일반 > 로그인 항목 > Karabiner 백그라운드 항목 ON
3. 드라이버 확장 프로그램: 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > `Karabiner-VirtualHIDDevice-Manager` ON

**참고**: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/

### 2. Shift+Space 한영전환이 안 되는 문제

#### 실패 1: fn+Space 키 전송
```json
"to": [{ "key_code": "spacebar", "modifiers": ["fn"] }]
```
- fn(Globe) 키는 macOS에서 특수 처리되어 Karabiner 가상 키보드로 시뮬레이션 불가

#### 실패 2: macOS symbolic hotkeys (defaults write)
```bash
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
  -dict-add 60 '{ enabled = 1; value = { parameters = (32, 49, 131072); type = standard; }; }'
```
- Karabiner 가상 키보드 환경에서 macOS symbolic hotkeys가 동작하지 않음

#### 실패 3: F18 중간 키 매핑
```json
"to": [{ "key_code": "f18" }]
```
- macOS symbolic hotkey를 F18로 설정해도 입력 소스 전환 트리거 안 됨

#### 실패 4: japanese_eisuu / japanese_kana 키 전송
```json
"to": [{ "key_code": "japanese_eisuu" }]
```
- JIS 키보드 전용 키코드로 한국어 입력 소스에는 동작하지 않음

#### 성공: select_input_source + input_source_if 조건
- Karabiner 공식 커뮤니티 규칙 기반
- `select_input_source`으로 입력 소스 직접 지정
- Karabiner 공식 문서에서 CJKV 언어에서 실패할 수 있다고 경고하지만, 실제로는 정상 동작
- **참고**: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/select-input-source/

### 3. 커뮤니티 규칙의 터미널 제외 문제

**증상**: Ctrl+C/V 등이 터미널에서만 동작하지 않음.

**원인**: `windows_shortcuts_on_macos.json` 원본 규칙이 `frontmost_application_unless` 조건으로 Terminal, iTerm2 등을 제외함. 터미널에서 Ctrl+C가 SIGINT 용도이기 때문.

**해결**: 터미널 관련 bundle_identifier를 제외 목록에서 제거.
- 제거 대상: `com.apple.Terminal`, `com.googlecode.iterm2`, `co.zeit.hyper`, `org.alacritty`, `net.kovidgoyal.kitty`, `com.github.wez.wezterm`
- 터미널에서 프로세스 중단이 필요하면 **Cmd+C** 사용

## 참고 자료

- Karabiner-Elements 공식 문서: https://karabiner-elements.pqrs.org/docs/
- macOS 필수 권한 설정: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/
- select_input_source 문서: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/select-input-source/
- 커뮤니티 규칙 저장소: https://ke-complex-modifications.pqrs.org/
- 윈도우 단축키 규칙 원본: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/windows_shortcuts_on_macos.json
- 한국어 전환 규칙 원본: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/ChangeInputSourceDirectlyForKorean.json
