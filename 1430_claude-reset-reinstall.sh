#!/bin/bash
set -euo pipefail

echo "==> Claude Code / Claude Desktop 완전 초기화 및 재설치"
echo ""

MODE="dry-run"
YES=0
REINSTALL=1
INCLUDE_PROJECT_LOCAL=0
STEP="all"

DESKTOP_DMG_URL="https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect"
DESKTOP_TARGET="$HOME/Applications/Claude.app"
DESKTOP_TMPDIR=""
DESKTOP_MOUNT_POINT=""

# Homebrew fallback 사용 시 암묵적인 brew auto-update 를 막고 단계 실행의 부작용을 줄인다.
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"

fail() {
  echo "오류: $*" >&2
  exit 1
}

cleanup_desktop_tmp() {
  if [ -n "${DESKTOP_MOUNT_POINT:-}" ] && mount | grep -F "on $DESKTOP_MOUNT_POINT " >/dev/null 2>&1; then
    hdiutil detach "$DESKTOP_MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  if [ -n "${DESKTOP_TMPDIR:-}" ] && [ -d "$DESKTOP_TMPDIR" ]; then
    rm -rf "$DESKTOP_TMPDIR"
  fi
}

trap cleanup_desktop_tmp EXIT

usage() {
  cat <<'EOF'
사용법:
  ./1430_claude-reset-reinstall.sh [옵션]

옵션:
  --dry-run                 삭제/설치하지 않고 후보만 출력 (기본값)
  --execute                 실제 삭제 및 재설치 수행
  --step NAME               지정한 한 단계만 실행
  --yes                     확인 질문을 자동 승인
  --reinstall               삭제 후 재설치 수행 (기본값)
  --skip-reinstall          삭제만 수행
  --include-project-local   홈 아래 프로젝트 로컬 .claude/.mcp.json 후보도 개별 확인 후 삭제
  -h, --help                도움말

단계:
  inventory                 삭제 후보와 근거 출력
  stop                      실행 중인 Claude 프로세스 종료
  uninstall-packages        npm/Homebrew Claude Code 패키지 제거
  delete-apps               Claude 앱 번들 삭제
  delete-user-data          현재 사용자 Claude 데이터 삭제
  delete-system             sudo 가 필요한 시스템/관리 정책 경로 삭제
  delete-keychain           Claude Keychain 인증정보 삭제
  reset-tcc                 Claude Desktop macOS 권한 초기화
  project-local             프로젝트 로컬 .claude/.mcp.json 후보 확인/삭제
  install-desktop           Claude Desktop 을 ~/Applications 에 설치
  install-code              Claude Code 를 ~/.local 에 설치
  verify                    설치 상태 검증
  verify-clean              초기화 대상 잔여 파일/Keychain 검증
  all                       전체 순차 실행 (기본값, 테스트 중에는 사용하지 말 것)

안전 정책:
  - 실제 파일 삭제는 --execute 지정 시에만 수행합니다.
  - 삭제는 rm -rfv 또는 sudo rm -rfv 로 verbose 출력합니다.
  - Claude 관련임이 확인된 고정 경로만 삭제합니다.
  - 앱 번들은 Info.plist 의 bundle id 를 확인한 뒤 삭제합니다.
  - Keychain secret 값은 읽거나 출력하지 않고, 항목 metadata 확인 후 삭제합니다.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      ;;
    --execute)
      MODE="execute"
      ;;
    --step)
      [ "$#" -ge 2 ] || fail "--step 값이 필요합니다."
      STEP="$2"
      shift
      ;;
    --yes)
      YES=1
      ;;
    --reinstall)
      REINSTALL=1
      ;;
    --skip-reinstall)
      REINSTALL=0
      ;;
    --include-project-local)
      INCLUDE_PROJECT_LOCAL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "알 수 없는 옵션: $1"
      ;;
  esac
  shift
done

DRY_RUN=1
if [ "$MODE" = "execute" ]; then
  DRY_RUN=0
fi

confirm() {
  local prompt="$1"

  if [ "$YES" -eq 1 ]; then
    echo "--- 자동 승인: $prompt"
    return 0
  fi

  printf "%s [y/N] " "$prompt"
  local answer
  read -r answer
  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

path_exists() {
  local path="$1"
  [ -e "$path" ] || [ -L "$path" ]
}

bundle_id() {
  local app="$1"
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Contents/Info.plist" 2>/dev/null || true
}

is_expected_bundle() {
  local app="$1"
  local expected_id="$2"
  local actual_id

  [ -d "$app" ] || return 1
  actual_id="$(bundle_id "$app")"
  [ "$actual_id" = "$expected_id" ]
}

print_path_info() {
  local path="$1"

  if path_exists "$path"; then
    ls -ld "$path"
  else
    echo "missing $path"
  fi
}

delete_path() {
  local path="$1"
  local use_sudo="${2:-0}"

  if ! path_exists "$path"; then
    echo "--- skip missing: $path"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$use_sudo" -eq 1 ]; then
      echo "[dry-run] sudo rm -rfv -- \"$path\""
    else
      echo "[dry-run] rm -rfv -- \"$path\""
    fi
    return 0
  fi

  if [ "$use_sudo" -eq 1 ]; then
    sudo rm -rfv -- "$path"
  else
    rm -rfv -- "$path"
  fi
}

find_matches() {
  local base="$1"
  local min_depth="$2"
  local max_depth="$3"
  local name="$4"

  [ -d "$base" ] || return 0
  find "$base" -mindepth "$min_depth" -maxdepth "$max_depth" -name "$name" -print 2>/dev/null | sort
}

print_find_matches() {
  local base="$1"
  local min_depth="$2"
  local max_depth="$3"
  local name="$4"
  local found=0
  local path

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found=1
    print_path_info "$path"
  done < <(find_matches "$base" "$min_depth" "$max_depth" "$name")

  if [ "$found" -eq 0 ]; then
    echo "missing $base/$name"
  fi
}

delete_find_matches() {
  local base="$1"
  local min_depth="$2"
  local max_depth="$3"
  local name="$4"
  local use_sudo="${5:-0}"
  local found=0
  local path

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found=1
    delete_path "$path" "$use_sudo"
  done < <(find_matches "$base" "$min_depth" "$max_depth" "$name")

  if [ "$found" -eq 0 ]; then
    echo "--- skip missing pattern: $base/$name"
  fi
}

delete_app_if_bundle_id() {
  local app="$1"
  local expected_id="$2"
  local use_sudo="${3:-0}"
  local actual_id

  if ! path_exists "$app"; then
    echo "--- skip missing app: $app"
    return 0
  fi

  actual_id="$(bundle_id "$app")"
  if [ "$actual_id" != "$expected_id" ]; then
    echo "--- skip app: $app"
    echo "    bundle id 불일치: ${actual_id:-<unknown>} != $expected_id"
    return 0
  fi

  delete_path "$app" "$use_sudo"
}

delete_keychain_item() {
  local service="$1"
  local account="${2:-}"

  local cmd=(security find-generic-password -s "$service")
  local delete_cmd=(security delete-generic-password -s "$service")

  if [ -n "$account" ]; then
    cmd+=(-a "$account")
    delete_cmd+=(-a "$account")
  fi

  if ! "${cmd[@]}" >/dev/null 2>&1; then
    echo "--- skip missing keychain item: service=$service account=${account:-<any>}"
    return 0
  fi

  echo "--- keychain item found: service=$service account=${account:-<any>}"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] security delete-generic-password -s \"$service\"${account:+ -a \"$account\"}"
    return 0
  fi

  if confirm "Keychain 항목 삭제: service=$service account=${account:-<any>}"; then
    "${delete_cmd[@]}"
  else
    echo "--- skip keychain item: service=$service account=${account:-<any>}"
  fi
}

quit_claude_processes() {
  echo ""
  echo "==> 실행 중인 Claude 프로세스 종료"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] osascript 으로 Claude 종료, pkill 로 Claude 관련 프로세스 종료"
    ps aux | rg -i '[C]laude|[a]nthropic' || true
    return 0
  fi

  osascript -e 'tell application id "com.anthropic.claudefordesktop" to quit' >/dev/null 2>&1 || true
  sleep 2
  pkill -f "/Applications/Claude.app" >/dev/null 2>&1 || true
  pkill -f "$HOME/Applications/Claude.app" >/dev/null 2>&1 || true
  pkill -f "Claude Code URL Handler.app" >/dev/null 2>&1 || true
  pkill -f "claude-code" >/dev/null 2>&1 || true
}

remove_npm_or_brew_claude_code() {
  echo ""
  echo "==> npm/Homebrew Claude Code 설치 흔적 제거"

  if command -v npm >/dev/null 2>&1; then
    if npm list -g --depth=0 @anthropic-ai/claude-code >/dev/null 2>&1; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] npm uninstall -g @anthropic-ai/claude-code"
      else
        npm uninstall -g @anthropic-ai/claude-code
      fi
    else
      echo "--- skip npm global package: @anthropic-ai/claude-code 없음"
    fi
  else
    echo "--- skip npm uninstall: npm 없음"
  fi

  if command -v brew >/dev/null 2>&1; then
    local cask
    for cask in claude-code "claude-code@latest"; do
      if brew list --cask "$cask" >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "[dry-run] brew uninstall --cask \"$cask\""
        else
          brew uninstall --cask "$cask"
        fi
      else
        echo "--- skip brew cask: $cask 없음"
      fi
    done
  else
    echo "--- skip brew uninstall: brew 없음"
  fi
}

scan_project_local_candidates() {
  local home="$HOME"

  {
    find "$home" \
      \( -path "$home/Library" -o -path "$home/.Trash" -o -path "$home/.claude" -o -path "$home/.codex" -o -path "$home/.cache" -o -path "$home/.npm" -o -path "$home/.local" -o -path "$home/node_modules" \) -prune \
      -o -name ".claude" -type d -print 2>/dev/null

    find "$home" \
      \( -path "$home/Library" -o -path "$home/.Trash" -o -path "$home/.claude" -o -path "$home/.codex" -o -path "$home/.cache" -o -path "$home/.npm" -o -path "$home/.local" -o -path "$home/node_modules" \) -prune \
      -o -name ".mcp.json" -type f -print 2>/dev/null \
      | while IFS= read -r path; do
          if grep -Eiq 'claude|anthropic' "$path" 2>/dev/null; then
            printf '%s\n' "$path"
          fi
        done
  } | sort
}

delete_project_local_candidates() {
  echo ""
  echo "==> 프로젝트 로컬 Claude 후보 확인"

  if [ "$INCLUDE_PROJECT_LOCAL" -ne 1 ]; then
    echo "--- skip: --include-project-local 옵션이 없어서 프로젝트 로컬 파일은 삭제하지 않음"
    return 0
  fi

  local candidates
  candidates="$(scan_project_local_candidates || true)"
  if [ -z "$candidates" ]; then
    echo "--- 프로젝트 로컬 후보 없음"
    return 0
  fi

  echo "$candidates"
  echo ""

  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] 프로젝트 로컬 후보: $path"
      continue
    fi
    if confirm "프로젝트 로컬 후보 삭제: $path"; then
      delete_path "$path" 0
    else
      echo "--- skip project-local: $path"
    fi
  done <<< "$candidates"
}

reset_tcc() {
  echo ""
  echo "==> macOS 권한(TCC) 초기화"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] tccutil reset All com.anthropic.claudefordesktop"
    return 0
  fi

  tccutil reset All com.anthropic.claudefordesktop >/dev/null 2>&1 || true
}

install_desktop_with_brew() {
  echo "--- fallback: Homebrew cask claude 를 ~/Applications 에 설치"
  command -v brew >/dev/null 2>&1 || fail "brew 가 없어 Claude Desktop fallback 설치를 진행할 수 없습니다."

  mkdir -p "$HOME/Applications"
  if brew list --cask claude >/dev/null 2>&1; then
    brew reinstall --cask claude --appdir="$HOME/Applications"
  else
    brew install --cask claude --appdir="$HOME/Applications"
  fi

  is_expected_bundle "$DESKTOP_TARGET" "com.anthropic.claudefordesktop" || fail "Homebrew 로 설치된 Claude.app bundle id 검증 실패"
  echo "--- Claude Desktop 설치 완료: $DESKTOP_TARGET"
}

download_and_install_desktop() {
  echo ""
  echo "==> Claude Desktop 재설치"
  echo "    대상: $DESKTOP_TARGET"

  local tmpdir
  local dmg
  local mount_point
  local source_app

  tmpdir="$(mktemp -d /tmp/claude-desktop-install.XXXXXX)"
  dmg="$tmpdir/Claude.dmg"
  DESKTOP_TMPDIR="$tmpdir"

  echo "--- 다운로드: $DESKTOP_DMG_URL"
  if ! curl -fL "$DESKTOP_DMG_URL" -o "$dmg"; then
    echo "--- 공식 DMG 직접 다운로드 실패. Cloudflare challenge 또는 네트워크 정책일 수 있습니다."
    rm -rf "$tmpdir"
    DESKTOP_TMPDIR=""
    install_desktop_with_brew
    return 0
  fi

  echo "--- DMG 마운트"
  mount_point="$(hdiutil attach "$dmg" -nobrowse -readonly | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
  [ -n "$mount_point" ] || fail "DMG 마운트 지점을 찾지 못했습니다."
  DESKTOP_MOUNT_POINT="$mount_point"

  source_app="$(find "$mount_point" -maxdepth 2 -name "Claude.app" -type d -print -quit)"
  [ -n "$source_app" ] || fail "DMG 안에서 Claude.app 을 찾지 못했습니다."
  is_expected_bundle "$source_app" "com.anthropic.claudefordesktop" || fail "다운로드한 Claude.app bundle id 검증 실패"

  mkdir -p "$HOME/Applications"
  if path_exists "$DESKTOP_TARGET"; then
    delete_app_if_bundle_id "$DESKTOP_TARGET" "com.anthropic.claudefordesktop" 0
  fi

  echo "--- 설치: $source_app -> $DESKTOP_TARGET"
  ditto "$source_app" "$DESKTOP_TARGET"
  xattr -dr com.apple.quarantine "$DESKTOP_TARGET" >/dev/null 2>&1 || true

  is_expected_bundle "$DESKTOP_TARGET" "com.anthropic.claudefordesktop" || fail "설치된 Claude.app bundle id 검증 실패"
  echo "--- Claude Desktop 설치 완료: $DESKTOP_TARGET"

  if [ -n "${mount_point:-}" ] && mount | grep -F "on $mount_point " >/dev/null 2>&1; then
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
  DESKTOP_MOUNT_POINT=""
  DESKTOP_TMPDIR=""
}

install_claude_code_native() {
  echo ""
  echo "==> Claude Code 재설치"
  echo "    공식 네이티브 설치 스크립트를 sudo 없이 실행합니다."

  curl -fsSL https://claude.ai/install.sh | bash

  if [ -x "$HOME/.local/bin/claude" ]; then
    "$HOME/.local/bin/claude" --version || true
  else
    echo "경고: $HOME/.local/bin/claude 를 찾지 못했습니다." >&2
  fi
}

verify_after_install() {
  echo ""
  echo "==> 설치 검증"

  if [ -d "$DESKTOP_TARGET" ]; then
    echo "--- Claude Desktop: $DESKTOP_TARGET"
    echo "    bundle id: $(bundle_id "$DESKTOP_TARGET")"
    codesign -dv "$DESKTOP_TARGET" 2>&1 | sed 's/^/    /' | sed -n '1,8p' || true
  else
    echo "경고: Claude Desktop 이 설치되지 않았습니다: $DESKTOP_TARGET" >&2
  fi

  if [ -x "$HOME/.local/bin/claude" ]; then
    echo "--- Claude Code: $HOME/.local/bin/claude"
    "$HOME/.local/bin/claude" --version || true
  else
    echo "경고: Claude Code 실행 파일이 없습니다: $HOME/.local/bin/claude" >&2
  fi

  case ":$PATH:" in
    *":$HOME/.local/bin:"*)
      echo "--- PATH OK: ~/.local/bin 포함"
      ;;
    *)
      echo "주의: 현재 PATH 에 ~/.local/bin 이 없습니다."
      echo "      필요하면 셸 설정에 추가하세요:"
      echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
      ;;
  esac
}

check_absent() {
  local path="$1"

  if path_exists "$path"; then
    echo "잔여 항목 발견: $path"
    return 1
  fi
  echo "--- absent OK: $path"
}

check_pattern_absent() {
  local base="$1"
  local min_depth="$2"
  local max_depth="$3"
  local name="$4"

  if [ -n "$(find_matches "$base" "$min_depth" "$max_depth" "$name")" ]; then
    echo "잔여 패턴 발견: $base/$name"
    find_matches "$base" "$min_depth" "$max_depth" "$name"
    return 1
  fi
  echo "--- absent OK: $base/$name"
}

check_keychain_absent() {
  local service="$1"
  local account="$2"

  if security find-generic-password -s "$service" -a "$account" >/dev/null 2>&1; then
    echo "잔여 Keychain 항목 발견: service=$service account=$account"
    return 1
  fi
  echo "--- keychain absent OK: service=$service account=$account"
}

verify_clean_state() {
  echo ""
  echo "==> 초기화 잔여 항목 검증"

  local failures=0
  local path
  local check_paths=(
    "/Applications/Claude.app"
    "$HOME/Library/Application Support/Claude"
    "$HOME/Library/Application Support/Claude-3p"
    "$HOME/Library/Preferences/com.anthropic.claudefordesktop.plist"
    "$HOME/Library/Caches/com.anthropic.claudefordesktop"
    "$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt"
    "$HOME/Library/HTTPStorages/com.anthropic.claudefordesktop"
    "$HOME/Library/Logs/Claude"
    "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"
    "$HOME/Library/Developer/Xcode/CodingAssistant/Agents/claude"
    "$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig"
    "$HOME/.claude.json.backup"
    "$HOME/Library/Caches/claude-cli-nodejs"
  )

  for path in "${check_paths[@]}"; do
    check_absent "$path" || failures=$((failures + 1))
  done

  check_pattern_absent "$HOME" 1 1 ".claude.json.backup.*" || failures=$((failures + 1))
  check_pattern_absent "$HOME/.vscode/extensions" 1 1 "anthropic.claude-code-*" || failures=$((failures + 1))
  check_pattern_absent "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*" || failures=$((failures + 1))
  check_keychain_absent "Claude Code-credentials" "$USER" || failures=$((failures + 1))
  check_keychain_absent "Claude Safe Storage" "Claude Key" || failures=$((failures + 1))

  if [ -n "$(scan_project_local_candidates || true)" ]; then
    echo "잔여 프로젝트 로컬 후보 발견:"
    scan_project_local_candidates || true
    failures=$((failures + 1))
  else
    echo "--- project-local absent OK"
  fi

  if [ "$failures" -gt 0 ]; then
    fail "초기화 잔여 항목 검증 실패: $failures"
  fi

  echo "--- 초기화 잔여 항목 검증 OK"
}

show_sources() {
  cat <<'EOF'

==> 참고 근거
  - Claude Code 설치/업데이트/삭제:
    https://code.claude.com/docs/en/getting-started
  - Claude Code 설정/히스토리:
    https://code.claude.com/docs/en/settings
  - Claude Code macOS Keychain 저장:
    https://code.claude.com/docs/en/iam
  - Claude Desktop 설치:
    https://support.claude.com/en/articles/10065433-install-claude-desktop
  - Claude Desktop macOS 배포 및 ~/Applications 업데이트 권한:
    https://support.claude.com/en/articles/12611117-deploy-claude-desktop-for-macos
  - Claude Desktop 엔터프라이즈 정책:
    https://support.claude.com/en/articles/12622667-enterprise-configuration-for-claude-desktop
EOF
}

USER_PATHS=(
  "$HOME/Library/Application Support/Claude"
  "$HOME/Library/Application Support/Claude-3p"
  "$HOME/Library/Preferences/com.anthropic.claudefordesktop.plist"
  "$HOME/Library/Caches/com.anthropic.claudefordesktop"
  "$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt"
  "$HOME/Library/HTTPStorages/com.anthropic.claudefordesktop"
  "$HOME/Library/Logs/Claude"
  "$HOME/Library/Saved Application State/com.anthropic.claudefordesktop.savedState"
  "$HOME/Library/WebKit/com.anthropic.claudefordesktop"
  "$HOME/Library/Cookies/com.anthropic.claudefordesktop.binarycookies"
  "$HOME/Library/Containers/com.anthropic.claudefordesktop"
  "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"
  "$HOME/Library/Developer/Xcode/CodingAssistant/Agents/claude"
  "$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig"
  "$HOME/.claude"
  "$HOME/.claude.json"
  "$HOME/.claude.json.backup"
  "$HOME/.claude/.credentials.json"
  "$HOME/.local/bin/claude"
  "$HOME/.local/share/claude"
  "$HOME/.local/state/claude"
  "$HOME/Library/Caches/claude-cli-nodejs"
)

SYSTEM_PATHS=(
  "/Library/Application Support/ClaudeCode"
  "/Library/Preferences/com.anthropic.claudecode.plist"
  "/Library/Preferences/com.anthropic.claudefordesktop.plist"
)

print_header() {
  echo "모드: $MODE"
  echo "단계: $STEP"
  echo "재설치: $([ "$REINSTALL" -eq 1 ] && echo yes || echo no)"
  echo "프로젝트 로컬 후보: $([ "$INCLUDE_PROJECT_LOCAL" -eq 1 ] && echo include || echo skip)"
  echo ""
}

step_inventory() {
  echo "==> 삭제 후보"
  print_path_info "/Applications/Claude.app"
  print_path_info "$HOME/Applications/Claude.app"
  print_path_info "$HOME/Applications/Claude Code URL Handler.app"

  for path in "${USER_PATHS[@]}"; do
    print_path_info "$path"
  done

  print_find_matches "$HOME/.vscode/extensions" 1 1 "anthropic.claude-code-*"
  print_find_matches "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*"
  print_find_matches "$HOME/Library/Application Support/Cursor/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*"
  print_find_matches "$HOME/Library/Application Support/Windsurf/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*"
  print_find_matches "$HOME/Library/Developer/Xcode/CodingAssistant/Agents/XcodeVersions" 2 2 "claude"
  print_find_matches "$HOME" 1 1 ".claude.json.backup.*"

  for plist in "$HOME"/Library/Preferences/ByHost/com.anthropic.claudefordesktop.ShipIt.*.plist; do
    [ -e "$plist" ] || continue
    print_path_info "$plist"
  done

  for path in "${SYSTEM_PATHS[@]}"; do
    print_path_info "$path"
  done

  if [ -d "/Library/Managed Preferences" ]; then
    find "/Library/Managed Preferences" \
      \( -name "com.anthropic.claudecode.plist" -o -name "com.anthropic.claudefordesktop.plist" \) \
      -print 2>/dev/null | sort | while IFS= read -r path; do
        print_path_info "$path"
      done
  fi

  show_sources

  if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "dry-run 완료. 실제 초기화는 각 단계를 하나씩 실행하세요:"
    echo "  ./1430_claude-reset-reinstall.sh --execute --step stop"
    echo "  ./1430_claude-reset-reinstall.sh --execute --step uninstall-packages"
    echo "  ./1430_claude-reset-reinstall.sh --execute --step delete-apps"
  fi
}

step_delete_apps() {
  echo ""
  echo "==> Claude 앱 번들 삭제"
  delete_app_if_bundle_id "/Applications/Claude.app" "com.anthropic.claudefordesktop" 1
  delete_app_if_bundle_id "$HOME/Applications/Claude.app" "com.anthropic.claudefordesktop" 0
  delete_app_if_bundle_id "$HOME/Applications/Claude Code URL Handler.app" "com.anthropic.claude-code-url-handler" 0
}

step_delete_user_data() {
  echo ""
  echo "==> 사용자 데이터 삭제"
  for path in "${USER_PATHS[@]}"; do
    delete_path "$path" 0
  done

  delete_find_matches "$HOME/.vscode/extensions" 1 1 "anthropic.claude-code-*" 0
  delete_find_matches "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*" 0
  delete_find_matches "$HOME/Library/Application Support/Cursor/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*" 0
  delete_find_matches "$HOME/Library/Application Support/Windsurf/CachedExtensionVSIXs" 1 1 "anthropic.claude-code-*" 0
  delete_find_matches "$HOME/Library/Developer/Xcode/CodingAssistant/Agents/XcodeVersions" 2 2 "claude" 0
  delete_find_matches "$HOME" 1 1 ".claude.json.backup.*" 0

  for plist in "$HOME"/Library/Preferences/ByHost/com.anthropic.claudefordesktop.ShipIt.*.plist; do
    [ -e "$plist" ] || continue
    delete_path "$plist" 0
  done
}

step_delete_system() {
  echo ""
  echo "==> 시스템 경로 삭제"
  for path in "${SYSTEM_PATHS[@]}"; do
    if path_exists "$path"; then
      if [ "$DRY_RUN" -eq 0 ] && ! confirm "sudo 로 시스템 경로 삭제: $path"; then
        echo "--- skip system path: $path"
        continue
      fi
      delete_path "$path" 1
    else
      echo "--- skip missing: $path"
    fi
  done

  if [ -d "/Library/Managed Preferences" ]; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      if [ "$DRY_RUN" -eq 0 ] && ! confirm "sudo 로 관리 정책 삭제: $path"; then
        echo "--- skip managed preference: $path"
        continue
      fi
      delete_path "$path" 1
    done < <(find "/Library/Managed Preferences" \
      \( -name "com.anthropic.claudecode.plist" -o -name "com.anthropic.claudefordesktop.plist" \) \
      -print 2>/dev/null | sort)
  fi
}

step_delete_keychain() {
  echo ""
  echo "==> Keychain 인증정보 삭제"
  delete_keychain_item "Claude Code-credentials" "$USER"
  delete_keychain_item "Claude Safe Storage" "Claude Key"
}

step_install_desktop() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "[dry-run] Claude Desktop 을 ~/Applications/Claude.app 에 재설치"
    return 0
  fi
  download_and_install_desktop
}

step_install_code() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "[dry-run] Claude Code 를 공식 네이티브 설치 스크립트로 ~/.local 에 재설치"
    return 0
  fi
  install_claude_code_native
}

run_step() {
  case "$1" in
    inventory)
      step_inventory
      ;;
    stop)
      quit_claude_processes
      ;;
    uninstall-packages)
      remove_npm_or_brew_claude_code
      ;;
    delete-apps)
      step_delete_apps
      ;;
    delete-user-data)
      step_delete_user_data
      ;;
    delete-system)
      step_delete_system
      ;;
    delete-keychain)
      step_delete_keychain
      ;;
    reset-tcc)
      reset_tcc
      ;;
    project-local)
      delete_project_local_candidates
      ;;
    install-desktop)
      step_install_desktop
      ;;
    install-code)
      step_install_code
      ;;
    verify)
      verify_after_install
      ;;
    verify-clean)
      verify_clean_state
      ;;
    all)
      step_inventory
      if [ "$DRY_RUN" -eq 0 ]; then
        echo ""
        confirm "위 Claude 관련 항목을 삭제하고 초기화할까요?" || fail "사용자가 취소했습니다."
      fi
      quit_claude_processes
      remove_npm_or_brew_claude_code
      step_delete_apps
      step_delete_user_data
      step_delete_system
      step_delete_keychain
      reset_tcc
      delete_project_local_candidates
      if [ "$REINSTALL" -eq 1 ]; then
        step_install_desktop
        step_install_code
        verify_after_install
      fi
      ;;
    *)
      fail "알 수 없는 단계: $1"
      ;;
  esac
}

print_header
run_step "$STEP"

echo ""
echo "완료"
