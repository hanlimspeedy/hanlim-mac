# Claude Code Compose Bar - 한글 입력 해결

## 목표

Claude Code 터미널 UI(React Ink)에서 한글(CJK) 입력 시 조합 중인 글자가 보이지 않는 문제를 해결한다.
이 문제는 Claude Code 자체의 한계이며, 한글 IME나 터미널 설정으로는 해결 불가능하다.

## 핵심 아이디어

**별도 입력창(Compose Bar)** 을 제공하여, 네이티브 텍스트 입력이 가능한 에디터에서 텍스트를 작성한 후 Claude Code에 붙여넣는다.

- Xshell(Windows)의 Compose Bar 개념을 tmux + micro로 구현
- Claude Code를 수정하지 않고, tmux 레벨에서 해결

## 동작 방식

```
┌──────────────────────────────┐
│  Claude Code (상단 유지)       │
│  → 출력 화면을 보면서 입력 가능  │
├──────────────────────────────┤
│  micro 에디터 (하단 8줄)       │  ← Ctrl+D로 열림
│  → 한글 입력 정상 동작          │  ← Ctrl+Q로 종료 → 자동 붙여넣기
└──────────────────────────────┘
```

1. `Ctrl+D` → tmux가 하단에 micro 에디터 분할창을 열음
2. micro에서 한글/영문 자유롭게 입력 (IME 조합 정상 표시)
3. `Ctrl+Q`로 종료 → 작성한 텍스트가 Claude Code 입력창에 자동 붙여넣기
4. micro는 autosave 모드라서 별도 저장 불필요

## 설치 (원커맨드)

```bash
# Ubuntu 서버
sudo apt install -y tmux micro git
git clone https://github.com/hanlimspeedy/hanlim-mac.git
bash hanlim-mac/1400_claude-compose-bar.sh

# macOS
brew install tmux micro
bash ~/mac-setup/1400_claude-compose-bar.sh
```

스크립트가 설치하는 것:
- `~/.local/bin/claude-compose` — Compose Bar 스크립트
- `~/.tmux.conf` — Ctrl+D 단축키 바인딩 (1줄 추가)
- PATH에 `~/.local/bin` 추가 (없는 경우)

## 사용법

```bash
tmux              # tmux 실행 (필수)
claude            # Claude Code 실행
# Ctrl+D          → 하단에 micro 입력창 열림
# 텍스트 입력      → 한글 조합이 정상적으로 보임
# Ctrl+Q          → 종료 + Claude Code에 자동 붙여넣기
```

## 필수 조건

- **tmux** — 분할창 기능 제공
- **micro** — 모드 전환 없는 터미널 에디터 (vim과 달리 insert mode 불필요)
- Claude Code는 반드시 **tmux 안에서** 실행해야 함

## 제한 사항

1. **tmux 필수** — tmux 없이는 Compose Bar 사용 불가. Claude Code를 항상 `tmux` 안에서 실행해야 함
2. **Ctrl+D 충돌** — Ctrl+D는 일반 쉘에서 EOF(종료) 키. Claude Code 실행 중에만 Compose Bar로 동작하고, 일반 쉘에서는 주의 필요
3. **직접 편집 제한** — micro의 autosave 모드에서 커서 이동/편집은 제한적일 수 있으나 프롬프트 입력에는 충분
4. **서버마다 설치 필요** — 각 서버에서 `1400_claude-compose-bar.sh` 실행 필요 (1회)
5. **GUI 에디터 아님** — 터미널 기반이므로 마우스 클릭 위치 지정 등은 제한적

## 시도했으나 실패한 방법들

| 방법 | 실패 이유 |
|------|----------|
| Claude Code 외부 에디터 (Ctrl+E) + vim | vim이 전체 화면으로 열려 Claude Code 출력이 안 보임 |
| Claude Code 외부 에디터 + GUI 에디터 | EDITOR/VISUAL 환경변수를 Claude Code가 무시함 (자동 IDE 감지) |
| TurboDraft (macOS 네이티브 앱) | macOS 전용, Ubuntu SSH 환경에서 사용 불가 |
| Hammerspoon 팝업 | macOS 전용 |
| iTerm2 Composer | macOS 전용, 서버 관리 기능 부족 |
| nano 에디터 | tmux가 Ctrl+X(종료키)를 가로채서 nano 종료 불가 |
| Warp 터미널 | Claude Code 자체 문제이므로 터미널 변경으로 해결 안 됨 |

## 파일 구조

```
~/.local/bin/claude-compose   # Compose Bar 메인 스크립트
~/.tmux.conf                  # Ctrl+D 바인딩 (1줄)
```

## 기술 상세

- `tmux run-shell`에서 `#{pane_id}`를 먼저 확장한 후 `split-window`에 전달 (핵심)
- `tmux split-window -v -l 8` — 하단 8줄 분할
- `tmux load-buffer` + `tmux paste-buffer -t` — 파일 내용을 원래 pane에 붙여넣기
- `micro -autosave 1` — 1초 간격 자동 저장 (종료 시 저장 확인 불필요)
