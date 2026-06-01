import CoreGraphics
import Foundation

final class HotstringManager {
    private var declarations: [HotstringDeclaration] = []
    private var buffer = ""
    private let maxBufferLength = 80
    private var replacementHandler: ((String) -> Void)?

    func register(_ declaration: HotstringDeclaration, replacementHandler: @escaping (String) -> Void) {
        declarations.append(declaration)
        self.replacementHandler = replacementHandler
    }

    func attach(to hotkeyManager: GlobalHotkeyManager) {
        hotkeyManager.observeKeyEvents { [weak self] event in
            self?.record(event: event)
        }
    }

    func reset() {
        declarations.removeAll()
        buffer.removeAll()
        replacementHandler = nil
    }

    private func record(event: CGEvent) {
        guard let chars = event.characters, !chars.isEmpty else {
            return
        }

        for char in chars {
            if char.isNewline || char.isWhitespace {
                buffer.removeAll()
                continue
            }

            buffer.append(char)
            if buffer.count > maxBufferLength {
                buffer.removeFirst(buffer.count - maxBufferLength)
            }

            if let match = declarations.first(where: { buffer.hasSuffix($0.trigger) }) {
                replacementHandler?(match.replacement)
                buffer.removeAll()
            }
        }
    }
}

private extension CGEvent {
    var characters: String? {
        var length = 0
        keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else {
            return nil
        }

        var buffer = [UniChar](repeating: 0, count: length)
        keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &buffer)
        return String(utf16CodeUnits: buffer, count: length)
    }
}
