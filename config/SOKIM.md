# 속 입력기 (SokIM) 한영전환

## 요약

| 항목 | 설정 |
|------|------|
| 입력기 | 속 입력기 (`com.kiding.inputmethod.sok.mode`) |
| 한영전환 | Shift+Space |
| Caps Lock | 대문자 고정만 (한영전환 안 함) |
| macOS 두벌식 | 끔 |
| ABC | 켜 둠 (암호 입력 등 macOS 기본 동작용) |
| Ctrl+Space / Ctrl+Option+Space 입력 소스 단축키 | 끔 |
| 앱/문서별 입력 소스 자동 전환 | 끔 |

- 저장소: https://github.com/kiding/SokIM (GPL-3.0)
- 설치: `brew install --cask sokim` → `/Library/Input Methods/SokIM.app`

## 왜 속 입력기인가

이전에는 Karabiner로 Shift+Space를 Caps Lock으로 바꿔 macOS의 ABC↔두벌식
입력 소스 전환을 탔다. 이 방식은 입력 소스 두 개를 오가는 비동기 전환이라
가끔 전환이 씹히거나 첫 글자가 영문으로 들어갔다. macOS 27.0.1에서는 한글
조합 중 입력 소스를 바꾸면 글자가 사라졌다가 두 번 들어가는 버그도 보고됐다
(ensky0/tildaz#715).

속 입력기는 한글/영문 엔진을 한 입력기 안에 두고 한영전환을 내부 상태로
처리한다. macOS 입력 소스 전환이 일어나지 않으므로 위 문제가 구조적으로
생기지 않는다. 한영키 입력을 Karabiner와 별개로 키보드에서 직접 읽으므로
Karabiner가 고장 나도 한영전환은 영향을 받지 않는다.

## 설치

```sh
./0400_karabiner-windows-keys.sh   # Karabiner Shift+Space 매핑 제거 (먼저)
./0410_sokim-input-method.sh       # 속 입력기 설치 + 입력 소스 교체 + 한영키 설정
./0410_sokim-input-method.sh status
```

macOS 12부터 다른 회사 입력기는 스크립트로 켤 수 없고 사용자가 직접 입력
소스에 추가해야 한다(`TISEnableInputSource`가 성공을 돌려주지만 켜지지 않고,
선택은 TIS -50으로 실패). 추가 전에는 스크립트가 설치만 하고 두벌식은 그대로
둔다. 아래 순서로 마무리한다.

1. `./0410_sokim-input-method.sh` (설치, 키보드 설정 화면이 열림)
2. 시스템 설정 → 키보드 → 텍스트 입력 → 입력 소스 `편집...` → `+` → 영어 →
   `속 입력기` → `추가`. 목록에 없으면 로그아웃 후 다시 로그인
3. `./0410_sokim-input-method.sh` 한 번 더 (속 입력기 선택, 두벌식 끔, 한영키 설정)
4. 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링: `속 입력기` 켬
5. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용: `속 입력기` 켬
6. `killall SokIM` (macOS가 속 입력기를 다시 띄워 권한을 반영)

권한 허용 전에는 입력이 안 될 수 있다. 1~3 사이에는 Shift+Space가 동작하지
않으므로 Caps Lock으로 한영을 바꾼다.

입력 소스와 한영키 설정은 사용자별이다. 다른 macOS 계정은 그 계정으로
로그인해 `0410_sokim-input-method.sh`를 실행한다.

한영키 자동 설정이 실패하면 메뉴바의 속 입력기 메뉴 → `한/A 전환` →
`⇧스페이스`만 체크하고 `한/A (⇪)`는 해제한다.

## 검증

1. `./0410_sokim-input-method.sh status`에서 `* com.kiding.inputmethod.sok.mode`
   가 선택되어 있고 두벌식(`com.apple.inputmethod.Korean.2SetKorean`)이 없다.
2. 터미널, Claude Code, Chrome, VS Code, 카카오톡에서 Shift+Space로 한영이
   바뀌고 바로 다음 글자부터 바뀐 언어로 입력된다.
3. 빠르게 `한글 English 한글`을 반복 입력해도 글자가 씹히지 않는다.
4. 암호 입력창(sudo, 로그인 창)을 거친 뒤 돌아와도 한글이 입력된다.
5. Caps Lock은 한영전환 없이 대문자 고정만 켜고 끈다.

## 알려진 제한

- 원격 접속(화면 공유, Jump Desktop 등)과 유니버설 컨트롤로 들어온 키 입력은
  받지 못한다. 속 입력기가 선택된 상태에서는 원격 세션 입력이 안 된다
  (SokIM #17, #63, #67). 원격으로 쓸 때는 메뉴바에서 ABC를 선택한다.
- 암호 입력 프롬프트가 지나간 뒤 한글이 안 되는 경우가 보고됐다(#65). 다른
  창에 갔다 돌아오면 풀린다.
- 일부 보안 프로그램과 충돌할 수 있다(#56).
- 두벌식만 지원하고 한자 입력이 없다.

## 제거 / 롤백

입력 소스를 macOS 두벌식으로 되돌리고 속 입력기를 제거한다.

```sh
./0410_sokim-input-method.sh uninstall
```

예전 Karabiner Shift+Space→Caps Lock 방식으로 돌아가려면 이 변경 이전 커밋의
파일을 복원해 실행한다.

```sh
git log --oneline -- 0410_sokim-input-method.sh   # 이 변경 커밋 확인
git revert <커밋>                                  # 또는 이전 커밋으로 파일 복원
./0400_input-switch-shift-space.sh
```

## 다시 도입하지 않을 방식

입력 소스(ABC↔두벌식)를 오가는 방식은 모두 같은 계열의 문제가 있었다.

- Karabiner `select_input_source`: 메뉴바만 한글이고 실제 입력은 영어로 남음
- Karabiner `Shift+Space → caps_lock`: 대체로 동작하지만 간헐적으로 씹힘
- `Ctrl+Space`/`Ctrl+Option+Space` 시스템 단축키: Karabiner 가상 키보드
  이벤트가 안정적으로 전환되지 않거나 순환 순서가 어긋남

## 입력 소스 ID

- 속 입력기: `com.kiding.inputmethod.sok`, `com.kiding.inputmethod.sok.mode`
- macOS 두벌식: `com.apple.inputmethod.Korean`, `com.apple.inputmethod.Korean.2SetKorean`
- ABC: `com.apple.keylayout.ABC`
