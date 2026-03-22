import Foundation
import GameController
import CoreGraphics

// 8BitDo Zero 2 Page Flip Tool
// A+Start(macOS 게임패드 모드)로 연결된 8BitDo Zero 2의
// 버튼을 Page Up/Down 키로 변환
//
// macOS는 8BitDo 버튼을 닌텐도 방식으로 해석 (A↔B, X↔Y 반전)
// 물리 A → buttonB, 물리 Y → buttonX

func sendKey(_ keyCode: CGKeyCode) {
    let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

let pageUp: CGKeyCode = 116
let pageDown: CGKeyCode = 121

func setupController(_ controller: GCController) {
    print("컨트롤러 연결됨: \(controller.vendorName ?? "Unknown")")

    if let gamepad = controller.extendedGamepad {
        // 물리 A버튼 (macOS에서 buttonB로 인식) → Page Up
        gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageUp) }
        }

        // 물리 Y버튼 (macOS에서 buttonX로 인식) → Page Down
        gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageDown) }
        }

        // R숄더 (X버튼쪽) → Page Up
        gamepad.rightShoulder.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageUp) }
        }

        // L숄더 (방향키쪽) → Page Down
        gamepad.leftShoulder.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageDown) }
        }

        print("  매핑 완료:")
        print("    R숄더(X쪽) / A버튼 → Page Up")
        print("    L숄더(방향키쪽) / Y버튼 → Page Down")
    } else if let micro = controller.microGamepad {
        micro.buttonA.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageUp) }
        }
        micro.buttonX.pressedChangedHandler = { _, _, pressed in
            if pressed { sendKey(pageDown) }
        }
        print("  MicroGamepad 매핑 완료")
    } else {
        print("  오류: 지원되는 게임패드 프로필 없음")
    }
}

NotificationCenter.default.addObserver(
    forName: .GCControllerDidConnect,
    object: nil,
    queue: .main
) { notification in
    if let controller = notification.object as? GCController {
        setupController(controller)
    }
}

NotificationCenter.default.addObserver(
    forName: .GCControllerDidDisconnect,
    object: nil,
    queue: .main
) { notification in
    if let controller = notification.object as? GCController {
        print("컨트롤러 해제됨: \(controller.vendorName ?? "Unknown")")
    }
}

for controller in GCController.controllers() {
    setupController(controller)
}

print("8BitDo PageFlip 실행 중... (Ctrl+C로 종료)")
if GCController.controllers().isEmpty {
    print("대기 중: 컨트롤러가 연결되지 않았습니다.")
}

RunLoop.main.run()
