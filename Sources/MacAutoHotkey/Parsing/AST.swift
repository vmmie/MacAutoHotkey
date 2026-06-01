import Foundation

struct AHKScript {
    var topLevelActions: [Action]
    var hotkeys: [HotkeyDeclaration]
    var hotstrings: [HotstringDeclaration]

    var requiresAccessibility: Bool {
        !hotkeys.isEmpty || !hotstrings.isEmpty || topLevelActions.contains { $0.requiresAccessibility }
    }
}

struct HotkeyDeclaration {
    var combo: HotkeyCombo
    var actions: [Action]
    var sourceLine: Int
}

struct HotstringDeclaration {
    var trigger: String
    var replacement: String
    var sourceLine: Int
}

enum Action {
    case assign(name: String, expression: Expression)
    case ifBlock(condition: Expression, actions: [Action])
    case loop(count: Expression, actions: [Action])
    case msgBox(Expression)
    case send(Expression)
    case mouseMove(x: Expression, y: Expression)
    case click(x: Expression?, y: Expression?)
    case sleep(milliseconds: Expression)

    var requiresAccessibility: Bool {
        switch self {
        case .assign, .msgBox, .sleep:
            false
        case .send, .mouseMove, .click:
            true
        case .ifBlock(_, let actions), .loop(_, let actions):
            actions.contains { $0.requiresAccessibility }
        }
    }
}

indirect enum Expression {
    case literal(AHKValue)
    case variable(String)
    case unary(operator: UnaryOperator, expression: Expression)
    case binary(left: Expression, operator: BinaryOperator, right: Expression)
}

enum UnaryOperator {
    case not
    case negative
}

enum BinaryOperator {
    case add
    case subtract
    case multiply
    case divide
    case concatenate
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
    case and
    case or
}
