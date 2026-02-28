# Karabiner-Elements 설정 가이드

## 현재 설정 요약

| 기능 | 방식 | 상태 |
|------|------|------|
| Ctrl ↔ Cmd 스왑 | simple_modifications | 완료 |
| Shift+Space 한영전환 | complex_modifications + select_input_source | 완료 |

## 트러블슈팅 기록

### 1. Karabiner 데몬(Core-Service)이 안 뜨는 문제

**증상**: Karabiner 설치 후 `karabiner_grabber`(현재 `Core-Service`로 통합됨)가 실행되지 않아 키 매핑이 전혀 동작하지 않음.

**원인**: macOS 보안 정책상 3가지 권한을 모두 수동으로 허용해야 함.

**해결**: 아래 3가지 권한 허용 후 **재부팅** 필수.
1. 입력 모니터링: 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링 > `Karabiner-Core-Service` ON
2. 로그인 항목: 시스템 설정 > 일반 > 로그인 항목 > Karabiner 백그라운드 항목 ON
3. 드라이버 확장 프로그램: 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > `Karabiner-VirtualHIDDevice-Manager` ON

**참고**: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/

### 2. Shift+Space 한영전환이 안 되는 문제

시도한 방법과 실패/성공 기록.

#### 실패 1: fn+Space 키 전송
```json
"to": [{ "key_code": "spacebar", "modifiers": ["fn"] }]
```
- Karabiner가 fn modifier를 macOS에 정상 전달하지 못함
- fn(Globe) 키는 macOS에서 특수 처리되어 Karabiner 가상 키보드로 시뮬레이션 불가

#### 실패 2: macOS symbolic hotkeys (defaults write)
```bash
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
  -dict-add 60 '{ enabled = 1; value = { parameters = (32, 49, 131072); type = standard; }; }'
```
- hotkey 60 (이전 입력 소스), hotkey 61 (다음 입력 소스) 모두 시도
- Karabiner 가상 키보드 환경에서 macOS symbolic hotkeys가 정상 동작하지 않음
- `activateSettings -u`로 반영해도 동작 안 함

#### 실패 3: F18 중간 키 매핑
```json
"to": [{ "key_code": "f18" }]
```
- Karabiner에서 Shift+Space → F18 전송
- macOS symbolic hotkey를 F18로 설정
- F18 키 이벤트가 macOS 입력 소스 전환을 트리거하지 못함

#### 실패 4: japanese_eisuu / japanese_kana 키 전송
```json
"to": [{ "key_code": "japanese_eisuu" }]
```
- JIS 키보드 전용 키코드로 한국어 입력 소스에는 동작하지 않음

#### 성공: select_input_source + input_source_if 조건
```json
{
    "type": "basic",
    "from": {
        "key_code": "spacebar",
        "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
    },
    "to": [{
        "select_input_source": {
            "input_source_id": "^com\\.apple\\.inputmethod\\.Korean\\.2SetKorean$"
        }
    }],
    "conditions": [{
        "type": "input_source_if",
        "input_sources": [{ "input_source_id": "^com\\.apple\\.keylayout\\.ABC$" }]
    }]
}
```
- 현재 입력 소스를 조건으로 판별하여 직접 전환
- 영어(ABC) → 한국어(두벌식), 한국어 → 영어 각각 별도 규칙
- Karabiner 공식 커뮤니티 규칙 기반
- **참고**: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/ChangeInputSourceDirectlyForKorean.json

### 3. select_input_source의 CJKV 제한 사항

Karabiner 공식 문서에 따르면 한국어/일본어/중국어/베트남어(CJKV) 입력 소스에서 `select_input_source`가 실패할 수 있다고 경고하지만, 실제로는 `input_source_id` 조건과 함께 사용하면 정상 동작함.

- **참고**: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/select-input-source/

## 설정 파일 구조 (karabiner.json)

### simple_modifications: Ctrl ↔ Cmd 스왑
물리 키보드의 Ctrl과 Cmd를 교체하여 윈도우 스타일 단축키 사용.
- Ctrl+C → 복사, Ctrl+V → 붙여넣기, Ctrl+Z → 실행취소 등

### complex_modifications: Shift+Space 한영전환
`select_input_source`로 입력 소스를 직접 지정하여 전환.
- `input_source_if` 조건으로 현재 입력 소스 판별
- 두벌식: `com.apple.inputmethod.Korean.2SetKorean`
- ABC: `com.apple.keylayout.ABC`

## 입력 소스 ID 확인 방법

현재 설치된 입력 소스 목록 확인:
```bash
defaults read com.apple.HIToolbox AppleEnabledInputSources
```

현재 활성 입력 소스 확인:
```bash
defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID
```

## 참고 자료

- Karabiner-Elements 공식 문서: https://karabiner-elements.pqrs.org/docs/
- macOS 필수 권한 설정: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/
- select_input_source 문서: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/select-input-source/
- 커뮤니티 규칙 저장소: https://ke-complex-modifications.pqrs.org/
- 한국어 전환 규칙 원본: https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/ChangeInputSourceDirectlyForKorean.json
- 윈도우 스타일 한영전환 (R_CMD): https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/switch_input_languages_with_rcmd_for_korean.json
