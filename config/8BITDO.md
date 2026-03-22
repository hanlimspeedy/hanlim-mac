# 8BitDo Zero 2 설정 가이드 (macOS)

## 개요

8BitDo Zero 2를 **키보드 모드**로 macOS에 연결하여, Karabiner-Elements의 디바이스별 매핑으로
L/R 버튼을 Page Up/Down으로 사용. 웹페이지를 편하게 읽기 위한 설정.

**핵심:** 다른 내장/외장 키보드는 전혀 영향받지 않음 (`device_if` 조건으로 8BitDo만 매핑).

## 연결 방법

### 1. 키보드 모드로 부팅
- **R + Start** 동시 누르기
- LED가 **5회 깜빡**이면 키보드 모드 진입 성공

### 2. 페어링 모드 진입
- **Select 버튼 3초** 길게 누르기
- LED가 빠르게 깜빡임

### 3. macOS Bluetooth 페어링
- 시스템 설정 > Bluetooth
- "8BitDo Zero 2" 선택하여 페어링
- 페어링 완료 시 LED 점등

### 4. 재연결
- 페어링 후에는 **Start 버튼**만 누르면 자동 재연결

## 연결 모드 종류

| 모드 | 부팅 조합 | LED 깜빡임 | 용도 |
|------|-----------|------------|------|
| macOS 게임패드 | A + Start | 3회 | 게임 |
| Android | B + Start | 1회 | Android |
| Xbox | X + Start | 2회 | Windows |
| Switch | Y + Start | 4회 | Nintendo |
| **키보드** | **R + Start** | **5회** | **페이지 넘기기 (이것 사용)** |

## 키보드 모드 버튼 → 키 매핑

| 물리 버튼 | 키보드 키 | Karabiner 매핑 |
|-----------|-----------|----------------|
| D-pad Up | C | (기본값) |
| D-pad Down | D | (기본값) |
| D-pad Left | E | (기본값) |
| D-pad Right | F | (기본값) |
| A | G | (기본값) |
| B | J | (기본값) |
| X | H | (기본값) |
| Y | I | (기본값) |
| **L shoulder** | **K** | **→ Page Up** |
| **R shoulder** | **M** | **→ Page Down** |
| Select | N | (기본값) |
| Start | O | (기본값) |

## Karabiner-Elements 설정

### 디바이스 식별자
- **Vendor ID:** 11720 (0x2DC8, 8BitDo)
- **Product ID:** 12848 (0x3250)

### 적용 원리
- `device_if` 조건으로 vendor_id + product_id가 일치하는 장치에서만 규칙 적용
- 일반 키보드에서 K, M 키를 눌러도 원래 동작 유지
- 8BitDo Zero 2에서만 K → Page Up, M → Page Down으로 변환

### 설정 확인
- Karabiner-Elements > Devices 탭에서 "8BitDo Zero 2" 확인
- Karabiner-EventViewer로 버튼별 key_code 확인 가능

## 트러블슈팅

### 연결 안 됨
1. 컨트롤러 전원 끄기 (Start 길게 누르기)
2. **R + Start**로 다시 키보드 모드 부팅 확인 (LED 5회 깜빡)
3. macOS Bluetooth에서 기존 페어링 삭제 후 재페어링

### 페이지 Up/Down 안 됨
1. Karabiner-Elements가 실행 중인지 확인
2. Karabiner > Devices 탭에서 8BitDo가 인식되는지 확인
3. EventViewer에서 버튼 누를 때 key_code가 k/m인지 확인
4. product_id가 다를 수 있음 → EventViewer에서 확인 후 karabiner.json 수정

### 다른 키보드에 영향이 가는 경우
- karabiner.json의 8BitDo 규칙에 `device_if` 조건이 있는지 확인
- vendor_id, product_id가 정확한지 확인

## 윈도우와의 차이

| | Windows | macOS |
|---|---|---|
| 연결 모드 | X + Start (Xbox) | R + Start (키보드) |
| 매핑 도구 | AntiMicroX | Karabiner-Elements |
| 매핑 방식 | 게임패드 → 키보드 | 키보드 → 키보드 (device_if) |

## 참고 자료
- [8BitDo Zero 2 키보드 모드 매뉴얼](https://manual.8bitdo.com/zero2/zero2_keyboard_mode.html)
- [8BitDo Zero 2 키맵 치트시트](http://denilson.sa.nom.br/gamepad-cheatsheet/8BitDo_Zero_2.html)
- [8BitDo Zero 2 FAQ](https://support.8bitdo.com/faq/zero2.html)
- [Karabiner-Elements device_if 문서](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/conditions/device/)
