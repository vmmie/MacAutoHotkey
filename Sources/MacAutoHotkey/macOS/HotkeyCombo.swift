import AppKit
import Foundation

struct HotkeyCombo: Hashable, CustomStringConvertible {
    var modifiers: ModifierSet
    var key: String

    var description: String {
        "\(modifiers.description)\(key)"
    }

    static func parse(_ text: String) throws -> HotkeyCombo {
        var modifiers = ModifierSet()
        var remainder = text.trimmingCharacters(in: .whitespaces)

        while let first = remainder.first {
            switch first {
            case "^":
                modifiers.insert(.control)
            case "!":
                modifiers.insert(.option)
            case "+":
                modifiers.insert(.shift)
            case "#":
                modifiers.insert(.command)
            default:
                let key = normalizeKeyName(remainder.trimmingCharacters(in: .whitespaces))
                guard !key.isEmpty else {
                    throw AHKError("Hotkey '\(text)' has no key.")
                }
                guard KeyCodeMap.namedKeys[key] != nil || KeyCodeMap.mouseButtons[key] != nil else {
                    throw AHKError("Unsupported hotkey key '\(key)' in '\(text)'.")
                }
                return HotkeyCombo(modifiers: modifiers, key: key)
            }
            remainder.removeFirst()
        }

        throw AHKError("Hotkey '\(text)' has no key.")
    }

    static func looksLikeHotkey(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return false
        }
        let key = parsedKeyName(from: text)
        return text.contains("^") || text.contains("!") || text.contains("+") || text.contains("#") || KeyCodeMap.mouseButtons[key] != nil
    }

    static func lineStartsWithHotkey(_ text: String) -> Bool {
        guard let range = text.range(of: "::") else {
            return false
        }
        return looksLikeHotkey(String(text[..<range.lowerBound]))
    }

    private static func parsedKeyName(from text: String) -> String {
        var remainder = text.trimmingCharacters(in: .whitespaces)
        while let first = remainder.first, ["^", "!", "+", "#"].contains(first) {
            remainder.removeFirst()
        }
        return normalizeKeyName(remainder)
    }

    private static func normalizeKeyName(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

struct ModifierSet: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: Int

    static let control = ModifierSet(rawValue: 1 << 0)
    static let option = ModifierSet(rawValue: 1 << 1)
    static let shift = ModifierSet(rawValue: 1 << 2)
    static let command = ModifierSet(rawValue: 1 << 3)

    var description: String {
        var parts: [String] = []
        if contains(.control) { parts.append("^") }
        if contains(.option) { parts.append("!") }
        if contains(.shift) { parts.append("+") }
        if contains(.command) { parts.append("#") }
        return parts.joined()
    }

    static func from(eventFlags: CGEventFlags) -> ModifierSet {
        var modifiers = ModifierSet()
        if eventFlags.contains(.maskControl) { modifiers.insert(.control) }
        if eventFlags.contains(.maskAlternate) { modifiers.insert(.option) }
        if eventFlags.contains(.maskShift) { modifiers.insert(.shift) }
        if eventFlags.contains(.maskCommand) { modifiers.insert(.command) }
        return modifiers
    }
}
