# Termius 설정 가이드

## 목표

macOS 기본 터미널 대신 **Termius를 기본 터미널로 사용**한다.

- 윈도우 스타일 Ctrl+C/V 복사/붙여넣기 지원 (Karabiner 연동)
- Local Terminal로 macOS 로컬 작업 가능
- SSH로 Ubuntu 서버 접속
- 한글 입력 정상 동작

## macOS 터미널 대신 Termius를 쓰는 이유

| 항목 | macOS Terminal | Termius |
|------|---------------|---------|
| Ctrl+C/V 복사/붙여넣기 | ❌ Karabiner 제외 (SIGINT 유지) | ✅ 윈도우 스타일 동작 |
| SSH 서버 관리 | ❌ 별도 설정 필요 | ✅ 내장 |
| Local Terminal | ✅ 기본 | ✅ 지원 (brew 버전만) |
| 한글 입력 | ✅ 자동 locale | ✅ .zshrc에 LANG 설정 필요 |
| 세션 동기화 | ❌ | ✅ 클라우드 동기화 |

## 현재 설정

### 1. Karabiner 연동 (자동 적용)

Termius는 Karabiner exclusion 목록에 **포함되지 않음** → 윈도우 스타일 단축키 적용됨.

- **Ctrl+C** → Cmd+C (복사)
- **Ctrl+V** → Cmd+V (붙여넣기)
- **Ctrl+X** → Cmd+X (잘라내기)
- **Ctrl+Z** → Cmd+Z (실행 취소)
- **Ctrl+Insert** → Cmd+C (복사)
- **Shift+Insert** → Cmd+V (붙여넣기)
- 기타 Ctrl+A/S/F/N/W/T 등 모든 윈도우 스타일 단축키 동작

참고: macOS Terminal.app(`com.apple.Terminal`)만 exclusion에 추가되어 Ctrl+C = SIGINT 유지.

**수정한 파일**: `config/karabiner.json`
- jq로 모든 `frontmost_application_unless` 조건의 `bundle_identifiers` 배열에 `^com\\.apple\\.Terminal$` 추가 (30개 규칙)
- Termius bundle ID (`com.termius-dmg.mac`)는 exclusion에 **포함하지 않음**
- 이 파일을 `~/.config/karabiner/karabiner.json`에 복사하면 Karabiner가 자동 반영

### 2. 한글 인코딩 (.zshrc)

Termius Local Terminal은 macOS 시스템 locale을 자동 상속하지 않음 (Terminal.app은 자동 설정).
`.zshrc`에 명시적으로 설정하여 해결:

```bash
export LANG="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
```

**수정한 파일**: `~/.zshrc`에 위 2줄 추가

### 3. Num Lock 숫자패드 탐색키 (Karabiner)

macOS는 Num Lock을 지원하지 않아 숫자패드가 항상 숫자만 전송됨.
Karabiner 변수 토글로 윈도우와 동일한 Num Lock 동작 구현:

- **Num Lock ON** (기본): 숫자 (0~9)
- **Num Lock OFF**: Insert, Home, End, PgUp, PgDn, 화살표, Delete

| Num Lock OFF 키 | 동작 |
|-----------------|------|
| Numpad 0 | Insert |
| Shift+Numpad 0 | 붙여넣기 (Cmd+V) |
| Ctrl+Numpad 0 | 복사 (Cmd+C) |
| Numpad 1 | End |
| Numpad 2 | ↓ |
| Numpad 3 | Page Down |
| Numpad 4 | ← |
| Numpad 6 | → |
| Numpad 7 | Home |
| Numpad 8 | ↑ |
| Numpad 9 | Page Up |
| Numpad . | Delete |

**주의**: Karabiner rules는 체이닝 안 됨. keypad_0 → insert 변환 후 Shift+Insert → Cmd+V 규칙이 재적용되지 않음. 그래서 Shift+keypad_0 → Cmd+V, Ctrl+keypad_0 → Cmd+C를 직접 매핑함.

**수정한 파일**: `config/karabiner.json`에 2개 규칙 추가
- `Num Lock OFF: Numpad keys => Navigation keys (Windows style)`
- `Num Lock toggle (clear key)`

### 4. Local Terminal

- **brew 버전만 지원** (App Store 버전은 샌드박스 제한으로 불가)
- 현재 brew로 설치되어 있으므로 정상 동작
- Termius > New Tab > Local Terminal로 열기

### 5. tmux 권장 사용

Termius Local Terminal에서도 `tmux`를 먼저 실행하고 작업하는 것을 권장:

- 마우스 드래그 → **자동 클립보드 복사** (별도 Ctrl+C 불필요)
- Ctrl+V → 붙여넣기
- 세션 유지 (창 닫아도 프로세스 살아있음)
- Claude Code Compose Bar (Ctrl+D) 사용 가능

tmux 마우스 드래그 복사 설정:

```
# ~/.tmux.conf
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
```

**수정한 파일**: `~/.tmux.conf`에 위 1줄 추가 (git 관리: `config/tmux.conf`)

## tmux 기본 사용법

### 시작/종료

```bash
tmux                    # 새 세션 시작
tmux ls                 # 세션 목록 확인
tmux attach             # 마지막 세션에 다시 연결
tmux attach -t 0        # 특정 세션에 연결
tmux kill-session -t 0  # 특정 세션 종료
exit                    # 현재 pane/window 종료
```

### 주요 단축키 (prefix = Ctrl+B)

| 단축키 | 동작 |
|--------|------|
| Ctrl+B, D | 세션 분리 (detach) — 세션은 백그라운드에서 유지 |
| Ctrl+B, C | 새 window 생성 |
| Ctrl+B, N | 다음 window |
| Ctrl+B, P | 이전 window |
| Ctrl+B, 숫자 | 해당 번호 window로 이동 |
| Ctrl+B, % | 세로 분할 (좌/우) |
| Ctrl+B, " | 가로 분할 (상/하) |
| Ctrl+B, 화살표 | pane 이동 |
| Ctrl+B, X | 현재 pane 닫기 |

### 복사/붙여넣기

- **마우스 드래그** → 자동으로 시스템 클립보드에 복사 (pbcopy 설정됨)
- **Ctrl+V** (→ Cmd+V) → 붙여넣기

### 커스텀 단축키 (현재 설정)

| 단축키 | 동작 |
|--------|------|
| Ctrl+D | Claude Code Compose Bar 열기 (하단 micro 에디터) |

### 주의사항

1. **tmux 안에서 tmux 실행 금지** — 중첩 세션이 됨. `tmux ls`로 기존 세션 확인 후 `tmux attach`로 복귀
2. **세션 정리** — 안 쓰는 세션은 `tmux kill-session -t 이름`으로 정리
3. **Ctrl+D 주의** — Claude Code 없이 빈 쉘에서 Ctrl+D 누르면 Compose Bar가 열림 (빈 쉘 종료 아님)

## 설치

```bash
~/mac-setup/1500_termius.sh
```

## 주의사항

1. **App Store 버전 사용 금지** — Local Terminal 미지원. 반드시 brew 또는 웹사이트 버전 사용
2. **SIGINT(프로세스 중단)** — Ctrl+C가 복사로 동작하므로, SIGINT는 Termius 자체 단축키 또는 Cmd+C(물리키)가 아닌 다른 방법 필요. tmux 사용 시 `Ctrl+C` 대신 `q`, `:kill-pane` 등 활용
3. **Termius 단축키 커스터마이징** — Preferences > Shortcuts에서 변경 가능 (GUI만, 파일 수정 불가)
4. **설정 동기화** — Termius 계정 로그인 시 서버 목록, 설정이 클라우드 동기화됨
