# 8BitDo Zero 2 설정 가이드 (macOS)

## 개요

8BitDo Zero 2를 **macOS 게임패드 모드**(A+Start)로 연결하고, Swift CLI 도구
(`8bitdo-pageflip/main.swift`)로 게임패드 버튼을 Page Up/Down/방향키로 변환.
웹페이지/PDF/만화를 편하게 넘기기 위한 설정.

**왜 게임패드 모드인가:** 키보드 모드(R+Start)는 빠른 연타 시 입력이 씹히는
문제가 있어서 GameController.framework 기반 게임패드 입력 방식으로 전환함.

## 빌드 / 실행

```bash
~/mac-setup/1900_8bitdo-pageflip.sh   # swiftc로 빌드
~/mac-setup/8bitdo-pageflip/8bitdo-pageflip   # 실행 (포그라운드)
```

종료는 `Ctrl+C`. 자동 시작은 등록하지 않음 — 필요할 때만 수동 실행.

## 연결 방법

### 1. 게임패드 모드로 부팅
- **A + Start** 동시 누르기
- LED **3회 깜빡**이면 macOS 게임패드 모드 진입 성공

### 2. 페어링 모드 진입
- **Select 버튼 3초** 길게 누르기
- LED 빠르게 깜빡임

### 3. macOS Bluetooth 페어링
- 시스템 설정 > Bluetooth
- "8BitDo Zero 2" 선택하여 페어링

### 4. 재연결
- 페어링 후에는 **Start 버튼**만 누르면 자동 재연결

## 연결 모드 종류

| 모드 | 부팅 조합 | LED 깜빡임 | 용도 |
|------|-----------|------------|------|
| **macOS 게임패드** | **A + Start** | **3회** | **이것 사용** |
| Android | B + Start | 1회 | Android |
| Xbox | X + Start | 2회 | Windows |
| Switch | Y + Start | 4회 | Nintendo |
| 키보드 | R + Start | 5회 | (입력 씹힘으로 미사용) |

## 버튼 매핑

macOS는 8BitDo의 A/B, X/Y를 닌텐도식(반전)으로 해석하므로,
Swift 코드는 `buttonA↔buttonB`, `buttonX↔buttonY`가 뒤집힌 채로 매핑함.

| 물리 버튼 | GameController API | 매핑 결과 |
|-----------|---------------------|-----------|
| A | `buttonB` | Page Up |
| Y | `buttonX` | Page Down |
| R 숄더 | `rightShoulder` | Page Up |
| L 숄더 | `leftShoulder` | Page Down |
| X | `buttonY` | ← (왼쪽 방향키, 뒤로) |
| B | `buttonA` | → (오른쪽 방향키, 앞으로) |

## 동작 원리

- `GCController` 알림으로 컨트롤러 연결/해제 감지
- `extendedGamepad` 프로필의 각 버튼에 `pressedChangedHandler` 등록
- 버튼 다운 시 `CGEvent`로 가상 키 이벤트(`pageUp=116`, `pageDown=121`,
  `leftArrow=123`, `rightArrow=124`) 합성하여 `cghidEventTap`에 post

## 권한

`CGEvent`로 키 입력을 합성하므로 **입력 모니터링/접근성 권한**이 필요할 수
있음. 처음 실행 시 macOS가 권한 요청 → 시스템 설정 > 개인정보 보호 및 보안
> 입력 모니터링(또는 접근성)에서 실행한 터미널/바이너리를 허용.

## 트러블슈팅

### 연결 안 됨
1. 컨트롤러 전원 끄기 (Start 길게 누르기)
2. **A + Start**로 게임패드 모드 재부팅 확인 (LED 3회 깜빡)
3. macOS Bluetooth에서 기존 페어링 삭제 후 재페어링

### 연결되었으나 키 입력 안 됨
1. 바이너리 실행 시 "컨트롤러 연결됨" 로그가 뜨는지 확인
2. 입력 모니터링/접근성 권한 부여 여부 확인
3. `extendedGamepad` 프로필이 nil이면 macOS 버전이 너무 낮거나 모드가 다름

### 다른 게임/앱이 컨트롤러를 가로챔
- 게임패드를 입력으로 쓰는 다른 앱(예: Steam)이 떠 있으면 충돌 가능
- 해당 앱 종료 후 PageFlip 재실행

## 참고 자료
- [8BitDo Zero 2 매뉴얼](https://support.8bitdo.com/faq/zero2.html)
- [GameController framework](https://developer.apple.com/documentation/gamecontroller)
- [CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent)
