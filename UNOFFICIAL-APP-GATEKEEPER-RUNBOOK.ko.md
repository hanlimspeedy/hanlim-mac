# 비공식 SecureCRT·Typora 실행 런북

이 문서는 `/Applications`에 설치된 비공식 또는 변조 가능성이 있는 SecureCRT와 Typora를 **macOS 전체 보안 설정을 바꾸지 않고**, 대상 앱만 확인·실행하기 위한 재현 절차다. 다른 AI나 작업자는 아래 순서를 지키고, 서명·격리 상태를 확인하지 않은 채 `sudo`, `spctl --master-disable`, 시스템 환경설정의 “모든 앱 허용”을 사용하지 않는다.

## 핵심 원칙

- 대상은 항상 정확한 앱 경로로 한정한다: `/Applications/SecureCRT.app`, `/Applications/Typora.app`.
- Gatekeeper 전체 허용, SIP 해제, `sudo xattr` 같은 전역·관리자 조작은 하지 않는다.
- `/Applications` 내부 앱은 macOS의 App Management/TCC 보호 때문에 `xattr`·`codesign` 수정이 거부될 수 있다. 이때 원본을 덮어쓰지 말고 사용자 홈에 새 사본을 만든다.
- 원본 앱은 보존한다. 실행본은 `/Users/iam/<앱>-<버전>-local.app`처럼 별도 이름을 사용한다.
- 비공식 서명은 신뢰의 증거가 아니다. 실행 성공을 “안전함” 또는 “정식 라이선스”로 보고하지 않는다.
- 라이선스 만료·등록 요구를 우회하지 않는다. 이 런북은 실행과 기본 창 확인까지만 다룬다.

## 1. 대상 확인과 정적 검사

```sh
find /Applications -maxdepth 1 -type d \( -iname 'SecureCRT.app' -o -iname 'Typora.app' \) -print

APP='/Applications/SecureCRT.app'       # 또는 /Applications/Typora.app
EXEC_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
spctl --assess --type execute --verbose=4 "$APP" 2>&1 || true
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 || true
codesign -dv --verbose=3 "$APP" 2>&1 | sed -n '1,32p'
xattr -l "$APP" 2>&1 || true
file "$APP/Contents/MacOS/$EXEC_NAME"
```

기록할 값은 버전, CPU(`arm64` 또는 `x86_64`), Gatekeeper 결과, `codesign` 결과, `com.apple.quarantine` 존재 여부다. `codesign`이 `invalid signature`이면 파일이 서명 후 변경된 것이다. `spctl`의 `rejected`만으로 파일 손상을 단정하지 말고 두 결과를 함께 기록한다.

## 2. 사용자 홈에 앱별 실행본 만들기

`/Applications`의 원본을 수정하지 않는다. 버전과 아키텍처를 확인해 이미 존재하는 경로를 덮어쓰지 않는다.

```sh
SRC='/Applications/SecureCRT.app'       # 또는 /Applications/Typora.app
APP='/Users/iam/SecureCRT-<버전>-<arm64|x86_64>-local.app'

if [ -e "$APP" ]; then
  echo "기존 실행본이 있으므로 새 고유 경로를 선택한다: $APP"; exit 2
fi
ditto "$SRC" "$APP"
xattr -cr "$APP"
xattr -p com.apple.quarantine "$APP" 2>&1 || true
```

`xattr -cr`은 이 사본에만 적용한다. `/Applications` 원본에서 `Operation not permitted`가 나와도 sudo로 재시도하지 않는다.

## 3. 서명 처리 분기

### SecureCRT

먼저 사본의 무결성을 검사한다.

```sh
codesign --verify --deep --strict --verbose=2 "$APP"
```

검증이 통과하면 재서명하지 않고 실행한다. 검증이 실패한 경우에만 **사본에 한해** 로컬 ad-hoc 서명을 시도한다.

```sh
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
```

재서명 뒤에는 `Authority`가 사라지고 `Signature=adhoc`가 될 수 있다. 이는 정식 개발자 서명이 아니므로 결과에 명시한다. SecureCRT가 실행되면 Quick Connect 또는 기본 창이 나타나는지 확인한다. 라이선스·평가 만료 창은 정상 실행 여부와 별개로 기록하고 우회하지 않는다.

### Typora

Typora는 비공식 배포본에서 ad-hoc 재서명 뒤 자체 검사를 하고 즉시 종료할 수 있다. 따라서 다음 순서를 지킨다.

1. 사본의 ad-hoc 재서명과 무결성 검증을 시도한다.
2. `open "$APP"` 뒤 5~6초 후 프로세스가 사라지면 재서명본을 사용하지 않는다.
3. 원본 실행 파일을 직접 실행해 창이 유지되는지 확인한다.

```sh
/Applications/Typora.app/Contents/MacOS/Typora
```

터미널에 `Could not find image named ...` 또는 WebKit deprecated 경고가 나와도 프로세스가 유지되고 편집 창이 뜨면 기본 실행은 성공이다. 원본 직접 실행은 Gatekeeper의 앱 아이콘 실행 경로를 우회할 수 있으므로, 이 사실을 완료 보고에 반드시 적는다.

## 4. 반복 실행용 Typora Launcher(선택)

Typora 원본 직접 실행이 매번 필요하면, 원본 바이너리를 호출하는 로컬 launcher를 만든다. 라이선스나 Gatekeeper를 우회하는 launcher가 아니라, 사용자가 지정한 바이너리를 실행하는 단순한 편의 도구다.

```sh
TMP='/Users/iam/Typora Launcher.app'
FINAL='/Users/iam/Applications/Typora Launcher.app'
if [ -e "$TMP" ] || [ -e "$FINAL" ]; then echo '기존 launcher를 덮어쓰지 않는다'; exit 2; fi
osacompile -o "$TMP" -e 'do shell script "nohup /Applications/Typora.app/Contents/MacOS/Typora >/dev/null 2>&1 &"'
xattr -cr "$TMP"
codesign --force --deep --sign - --timestamp=none "$TMP"
mv "$TMP" "$FINAL"
codesign --verify --deep --strict --verbose=2 "$FINAL"
```

launcher를 한 번 `open "$FINAL"`로 테스트하고 Typora 프로세스가 유지되는지 확인한다. 기존 Typora가 이미 실행 중이면 중복 창/프로세스가 생길 수 있으므로, 사용자가 열어 둔 문서가 없는지 확인한 뒤 불필요한 프로세스만 정리한다.

## 5. 실행 및 UI 확인

터미널에서 정확한 경로로 실행한다.

```sh
open '/Users/iam/SecureCRT-<버전>-<arch>-local.app'
open '/Users/iam/Applications/Typora Launcher.app'
```

실행 후 다음을 확인한다.

```sh
pgrep -afil 'SecureCRT|Typora' || true
```

Computer Use를 사용할 수 있는 AI는 앱 상태/접근성 트리를 조회해 다음을 확인한다.

- SecureCRT: `Quick Connect` 또는 기본 세션 창이 보이는가.
- Typora: 제목 없는 문서와 `Start writing...` 편집 영역이 보이는가.
- “손상되었기 때문에 열 수 없습니다” 창이 뜨면 원본을 반복 실행하지 말고 사본·격리·서명 분기를 다시 확인한다.

## 6. 성공 판정과 보고 형식

완료 보고에는 다음을 포함한다.

1. 원본 경로와 실제 실행본 경로.
2. 앱 버전과 CPU 아키텍처.
3. `xattr` 격리 속성을 앱 사본에만 제거했는지.
4. 서명 검증 결과와 ad-hoc 재서명 여부.
5. 실제 창 이름과 프로세스가 유지됐는지.
6. 라이선스/평가판 만료 또는 정식 인증서 부재 같은 제한.

예시:

```text
SecureCRT 9.6.3 arm64 실행 확인.
원본: /Applications/SecureCRT.app
실행본: /Users/iam/SecureCRT-9.6.3-arm64-local.app
앱 사본의 quarantine만 제거했고 전역 Gatekeeper는 변경하지 않음.
codesign --verify --deep 통과, Quick Connect 창 확인.
```

## 7. 금지 사항과 복구

다음 명령은 사용하지 않는다.

```sh
sudo spctl --master-disable
sudo defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool NO
sudo xattr -dr com.apple.quarantine /Applications
```

작업이 실패하면 원본을 복원하려고 덮어쓰지 말고, 사본을 닫은 뒤 원본의 서명·격리 상태부터 다시 기록한다. 설정·문서·접속 정보가 열려 있을 수 있으므로 앱 번들을 임의 삭제하지 않는다.
