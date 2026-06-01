import AppKit
import Foundation

final class GlobalHotkeyManager {
    typealias Handler = () -> Void
    typealias KeyObserver = (CGEvent) -> Void

    private var handlers: [HotkeyCombo: Handler] = [:]
    private var keyObservers: [KeyObserver] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func register(combo: HotkeyCombo, handler: @escaping Handler) {
        handlers[combo] = handler
    }

    func observeKeyEvents(_ observer: @escaping KeyObserver) {
        keyObservers.append(observer)
    }

    func start() throws {
        guard eventTap == nil else {
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            throw AHKError("Could not create keyboard event tap. Grant Accessibility/Input Monitoring permission and retry.")
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handlers.removeAll()
        keyObservers.removeAll()
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown || type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown else {
            return Unmanaged.passUnretained(event)
        }

        keyObservers.forEach { $0(event) }

        let modifiers = ModifierSet.from(eventFlags: event.flags)
        guard let key = keyName(for: event, type: type) else {
            return Unmanaged.passUnretained(event)
        }

        let combo = HotkeyCombo(modifiers: modifiers, key: key)
        if let handler = handlers[combo] {
            let scheduled = ScheduledHotkeyHandler(handler)
            RunLoop.main.perform {
                scheduled()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func keyName(for event: CGEvent, type: CGEventType) -> String? {
        switch type {
        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            return KeyCodeMap.keyNamesByCode[keyCode]
        case .leftMouseDown:
            return "lbutton"
        case .rightMouseDown:
            return "rbutton"
        case .otherMouseDown:
            let rawButton = event.getIntegerValueField(.mouseEventButtonNumber)
            return KeyCodeMap.mouseButtonNames[rawButton]
        default:
            return nil
        }
    }
}

private struct ScheduledHotkeyHandler: @unchecked Sendable {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func callAsFunction() {
        handler()
    }
}

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handle(proxy: proxy, type: type, event: event)
}
