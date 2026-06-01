import Foundation

final class AHKScriptingRuntime {
    private let script: AHKScript
    private let automation: MacAutomation
    private let hotkeyManager: GlobalHotkeyManager
    private let hotstringManager: HotstringManager
    private let environment = Environment()
    private(set) var isRunning = false
    var isPersistent: Bool {
        !script.hotkeys.isEmpty || !script.hotstrings.isEmpty
    }

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

    func start(enterRunLoop: Bool = true, announce: Bool = true) throws {
        guard !script.requiresAccessibility || automation.hasAccessibilityPermission(prompt: true) else {
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

        if !isPersistent {
            return
        }

        try hotkeyManager.start()
        hotstringManager.attach(to: hotkeyManager)
        isRunning = true

        if announce {
            print("macahk is running. Press Ctrl+C to stop.")
        }
        if enterRunLoop {
            RunLoop.main.run()
        }
    }

    func stop() {
        hotkeyManager.stop()
        hotstringManager.reset()
        isRunning = false
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
        case .ifBlock(let condition, let actions):
            if evaluate(condition).booleanValue {
                try execute(actions)
            }
        case .loop(let count, let actions):
            let iterations = max(0, Int(evaluate(count).numberValue ?? 0))
            guard iterations > 0 else {
                return
            }
            for currentIndex in 1...iterations {
                environment.set("A_Index", value: .number(Double(currentIndex)))
                try execute(actions)
            }
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
            return value
        case .variable(let name):
            return environment.get(name)
        case .unary(let op, let expression):
            let value = evaluate(expression)
            switch op {
            case .not:
                return .boolean(!value.booleanValue)
            case .negative:
                return .number(-(value.numberValue ?? 0))
            }
        case .binary(let left, let op, let right):
            return evaluateBinary(left: evaluate(left), operator: op, right: evaluate(right))
        }
    }

    private func evaluateBinary(left: AHKValue, operator op: BinaryOperator, right: AHKValue) -> AHKValue {
        switch op {
        case .add:
            return .number((left.numberValue ?? 0) + (right.numberValue ?? 0))
        case .subtract:
            return .number((left.numberValue ?? 0) - (right.numberValue ?? 0))
        case .multiply:
            return .number((left.numberValue ?? 0) * (right.numberValue ?? 0))
        case .divide:
            let divisor = right.numberValue ?? 0
            return divisor == 0 ? .empty : .number((left.numberValue ?? 0) / divisor)
        case .concatenate:
            return .string(left.description + right.description)
        case .equal:
            return .boolean(compare(left, right) == .orderedSame)
        case .notEqual:
            return .boolean(compare(left, right) != .orderedSame)
        case .lessThan:
            return .boolean(compare(left, right) == .orderedAscending)
        case .lessThanOrEqual:
            let comparison = compare(left, right)
            return .boolean(comparison == .orderedAscending || comparison == .orderedSame)
        case .greaterThan:
            return .boolean(compare(left, right) == .orderedDescending)
        case .greaterThanOrEqual:
            let comparison = compare(left, right)
            return .boolean(comparison == .orderedDescending || comparison == .orderedSame)
        case .and:
            return .boolean(left.booleanValue && right.booleanValue)
        case .or:
            return .boolean(left.booleanValue || right.booleanValue)
        }
    }

    private func compare(_ left: AHKValue, _ right: AHKValue) -> ComparisonResult {
        if let leftNumber = left.numberValue, let rightNumber = right.numberValue {
            if leftNumber < rightNumber {
                return .orderedAscending
            }
            if leftNumber > rightNumber {
                return .orderedDescending
            }
            return .orderedSame
        }
        return left.description.localizedStandardCompare(right.description)
    }

    private func pointFromExpressions(x: Expression, y: Expression) throws -> CGPoint {
        guard let xValue = evaluate(x).numberValue, let yValue = evaluate(y).numberValue else {
            throw AHKError("Mouse coordinates must be numeric.")
        }
        return CGPoint(x: xValue, y: yValue)
    }
}
