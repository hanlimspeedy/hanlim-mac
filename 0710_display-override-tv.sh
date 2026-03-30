#!/bin/bash
set -e

echo "==> LG 43U712A 디스플레이 오버라이드 설치 (TV→모니터 인식)"

# LG 43U712A: VendorID=0x1e6d (GSM), ProductID=0x9ea4
VENDOR_DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-1e6d"
OVERRIDE_FILE="$VENDOR_DIR/DisplayProductID-9ea4"

if [ -f "$OVERRIDE_FILE" ]; then
  echo "이미 설치됨: $OVERRIDE_FILE"
  exit 0
fi

echo "오버라이드 파일 생성 중..."
sudo mkdir -p "$VENDOR_DIR"

sudo tee "$OVERRIDE_FILE" >/dev/null <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DisplayProductName</key>
    <string>LG ULTRAFINE</string>
    <key>DisplayIsTV</key>
    <false/>
</dict>
</plist>
PLIST

echo ""
echo "완료: LG 43U712A 디스플레이 오버라이드 설치됨"
echo "  - macOS가 TV 대신 모니터로 인식"
echo "  - Night Shift(따뜻한 색상) 사용 가능"
echo ""
echo "※ 재부팅 후 적용됩니다."
echo "※ 되돌리기: sudo rm $OVERRIDE_FILE"
