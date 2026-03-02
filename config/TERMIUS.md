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
- 기타 Ctrl+A/S/F/N/W/T 등 모든 윈도우 스타일 단축키 동작

참고: macOS Terminal.app만 exclusion에 추가되어 Ctrl+C = SIGINT 유지.

### 2. 한글 인코딩 (.zshrc)

Termius Local Terminal은 macOS 시스템 locale을 자동 상속하지 않음.
`.zshrc`에 명시적으로 설정하여 해결:

```bash
export LANG="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
```

### 3. Local Terminal

- **brew 버전만 지원** (App Store 버전은 샌드박스 제한으로 불가)
- 현재 brew로 설치되어 있으므로 정상 동작
- Termius > New Tab > Local Terminal로 열기

### 4. tmux 마우스 드래그 복사

tmux에서 마우스 드래그 → 시스템 클립보드 자동 복사 설정:

```
# ~/.tmux.conf
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
```

Ctrl+V (→ Cmd+V)로 붙여넣기 가능.

## 설치

```bash
~/mac-setup/1500_termius.sh
```

## 주의사항

1. **App Store 버전 사용 금지** — Local Terminal 미지원. 반드시 brew 또는 웹사이트 버전 사용
2. **SIGINT(프로세스 중단)** — Ctrl+C가 복사로 동작하므로, SIGINT는 Termius 자체 단축키 또는 Cmd+C(물리키)가 아닌 다른 방법 필요. tmux 사용 시 `Ctrl+C` 대신 `q`, `:kill-pane` 등 활용
3. **Termius 단축키 커스터마이징** — Preferences > Shortcuts에서 변경 가능 (GUI만, 파일 수정 불가)
4. **설정 동기화** — Termius 계정 로그인 시 서버 목록, 설정이 클라우드 동기화됨
