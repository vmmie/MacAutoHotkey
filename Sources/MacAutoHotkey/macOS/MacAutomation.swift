import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class MacAutomation {
    private lazy var keyboardLayout = KeyboardLayout()

    func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    func showMessage(_ message: String) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                Self.showMessageOnMain(message)
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    Self.showMessageOnMain(message)
                }
            }
        }
    }

    @MainActor
    private static func showMessageOnMain(_ message: String) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func sendText(_ text: String) {
        for char in text {
            send(character: char)
            usleep(3_000)
        }
    }

    func moveMouse(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }

    func clickCurrentLocation() {
        let location = NSEvent.mouseLocation
        let mainHeight = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let quartzPoint = CGPoint(x: location.x, y: mainHeight - location.y)
        click(at: quartzPoint)
    }

    func click(at point: CGPoint) {
        moveMouse(to: point)
        postMouse(type: .leftMouseDown, point: point)
        postMouse(type: .leftMouseUp, point: point)
    }

    func replaceTypedText(triggerLength: Int, with replacement: String) {
        for _ in 0..<triggerLength {
            postKey(keyCode: 51, keyDown: true, flags: [])
            postKey(keyCode: 51, keyDown: false, flags: [])
            usleep(2_000)
        }
        sendText(replacement)
    }

    private func send(character: Character) {
        guard let mapping = keyboardLayout.mapping(for: character) else {
            pasteViaClipboard(String(character))
            return
        }

        postKey(keyCode: mapping.keyCode, keyDown: true, flags: mapping.flags)
        postKey(keyCode: mapping.keyCode, keyDown: false, flags: mapping.flags)
    }

    private func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postKey(keyCode: 9, keyDown: true, flags: .maskCommand)
        postKey(keyCode: 9, keyDown: false, flags: .maskCommand)

        if let previous {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }

    private func postKey(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func postMouse(type: CGEventType, point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }
}
