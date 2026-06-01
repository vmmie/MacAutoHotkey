import Carbon
import CoreGraphics
import Foundation

struct KeyboardLayoutMapping {
    var keyCode: CGKeyCode
    var flags: CGEventFlags
}

final class KeyboardLayout {
    private let mappings: [Character: KeyboardLayoutMapping]
    let inputSourceName: String

    init() {
        let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        inputSourceName = (source.flatMap {
            TISGetInputSourceProperty($0, kTISPropertyLocalizedName)
        }.map {
            Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
        }) ?? "Unknown"

        guard
            let source,
            let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            mappings = [:]
            return
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue()
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        mappings = Self.buildMappings(keyboardLayout: keyboardLayout)
    }

    func mapping(for character: Character) -> KeyboardLayoutMapping? {
        mappings[character]
    }

    func describe(characters: String) -> [(character: Character, mapping: KeyboardLayoutMapping?)] {
        characters.map { ($0, mapping(for: $0)) }
    }

    private static func buildMappings(keyboardLayout: UnsafePointer<UCKeyboardLayout>) -> [Character: KeyboardLayoutMapping] {
        var result: [Character: KeyboardLayoutMapping] = [:]
        let modifierStates: [(flags: CGEventFlags, carbonModifiers: UInt32)] = [
            ([], 0),
            (.maskShift, UInt32(shiftKey >> 8)),
            (.maskAlternate, UInt32(optionKey >> 8)),
            ([.maskShift, .maskAlternate], UInt32((shiftKey | optionKey) >> 8))
        ]

        for keyCode in CGKeyCode(0)...CGKeyCode(127) {
            for state in modifierStates {
                guard let character = translate(
                    keyCode: keyCode,
                    carbonModifiers: state.carbonModifiers,
                    keyboardLayout: keyboardLayout
                ) else {
                    continue
                }

                if result[character] == nil || state.flags.isEmpty {
                    result[character] = KeyboardLayoutMapping(keyCode: keyCode, flags: state.flags)
                }
            }
        }

        result["\n"] = KeyboardLayoutMapping(keyCode: KeyCodeMap.namedKeys["return"] ?? 36, flags: [])
        result["\t"] = KeyboardLayoutMapping(keyCode: KeyCodeMap.namedKeys["tab"] ?? 48, flags: [])
        result[" "] = KeyboardLayoutMapping(keyCode: KeyCodeMap.namedKeys["space"] ?? 49, flags: [])
        return result
    }

    private static func translate(
        keyCode: CGKeyCode,
        carbonModifiers: UInt32,
        keyboardLayout: UnsafePointer<UCKeyboardLayout>
    ) -> Character? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            carbonModifiers,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length == 1 else {
            return nil
        }

        let scalarValue = UInt32(chars[0])
        guard let scalar = UnicodeScalar(scalarValue) else {
            return nil
        }
        let character = Character(scalar)
        guard !character.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return character
    }
}
