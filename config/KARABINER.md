# Karabiner-Elements 설정 가이드

## 현재 설정 요약

| 기능 | 방식 | 상태 |
|------|------|------|
| 윈도우 스타일 단축키 (13개) | complex_modifications | 완료 |
| Num Lock 숫자패드 탐색키 | complex_modifications + variable toggle | 완료 |
| Shift+Space 한영전환 | complex_modifications + select_input_source | 완료 |

## 적용된 단축키 목록

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

### 방식
`select_input_source`로 입력 소스를 직접 지정하여 전환.
- `input_source_if` 조건으로 현재 입력 소스 판별
- 영어(ABC) → 한국어(두벌식), 한국어 → 영어 각각 별도 규칙

### 입력 소스 ID
- 두벌식: `com.apple.inputmethod.Korean.2SetKorean`
- ABC: `com.apple.keylayout.ABC`

## 참고 자료

- Karabiner-Elements 공식 문서: https://karabiner-elements.pqrs.org/docs/
- macOS 필수 권한 설정: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/
- 커뮤니티 규칙 저장소: https://ke-complex-modifications.pqrs.org/
