import Foundation

final class AHKScriptingRuntime {
    private let script: AHKScript
    private let automation: MacAutomation
    private let hotkeyManager: GlobalHotkeyManager
    private let hotstringManager: HotstringManager
    private let environment = Environment()

    init(
        script: AHKScript,
        automation: MacAutomation,
        hotkeyManager: GlobalHotkeyManager,
        hotstringManager: HotstringManager
    ) {
        self.script = script
        self.automation = automation
        self.hotkeyManager = hotkeyManager
        self.hotstringManager = hotstringManager
    }

    func start() throws {
        guard automation.hasAccessibilityPermission(prompt: true) else {
            throw AHKError("Accessibility permission is required for hotkeys and input automation.")
        }

        try execute(script.topLevelActions)

        for hotkey in script.hotkeys {
            hotkeyManager.register(combo: hotkey.combo) { [weak self] in
                guard let self else {
                    return
                }
                do {
                    try self.execute(hotkey.actions)
                } catch {
                    fputs("macahk hotkey error at line \(hotkey.sourceLine): \(error)\n", stderr)
                }
            }
        }

        for hotstring in script.hotstrings {
            hotstringManager.register(hotstring) { [weak self] replacement in
                self?.automation.replaceTypedText(triggerLength: hotstring.trigger.count, with: replacement)
            }
        }

        if script.hotkeys.isEmpty && script.hotstrings.isEmpty {
            return
        }

        try hotkeyManager.start()
        hotstringManager.attach(to: hotkeyManager)

        print("macahk is running. Press Ctrl+C to stop.")
        RunLoop.main.run()
    }

    private func execute(_ actions: [Action]) throws {
        for action in actions {
            try execute(action)
        }
    }

    private func execute(_ action: Action) throws {
        switch action {
        case .assign(let name, let expression):
            environment.set(name, value: evaluate(expression))
        case .msgBox(let expression):
            automation.showMessage(evaluate(expression).description)
        case .send(let expression):
            automation.sendText(evaluate(expression).description)
        case .mouseMove(let x, let y):
            let point = try pointFromExpressions(x: x, y: y)
            automation.moveMouse(to: point)
        case .click(let x, let y):
            if let x, let y {
                automation.click(at: try pointFromExpressions(x: x, y: y))
            } else {
                automation.clickCurrentLocation()
            }
        case .sleep(let expression):
            let milliseconds = evaluate(expression).numberValue ?? 0
            Thread.sleep(forTimeInterval: max(0, milliseconds) / 1000)
        }
    }

    private func evaluate(_ expression: Expression) -> AHKValue {
        switch expression {
        case .literal(let value):
            value
        case .variable(let name):
            environment.get(name)
        }
    }

    private func pointFromExpressions(x: Expression, y: Expression) throws -> CGPoint {
        guard let xValue = evaluate(x).numberValue, let yValue = evaluate(y).numberValue else {
            throw AHKError("Mouse coordinates must be numeric.")
        }
        return CGPoint(x: xValue, y: yValue)
    }
}
