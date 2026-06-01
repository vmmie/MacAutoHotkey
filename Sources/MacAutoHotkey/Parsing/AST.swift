import Foundation

struct AHKScript {
    var topLevelActions: [Action]
    var hotkeys: [HotkeyDeclaration]
    var hotstrings: [HotstringDeclaration]
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
    case msgBox(Expression)
    case send(Expression)
    case mouseMove(x: Expression, y: Expression)
    case click(x: Expression?, y: Expression?)
    case sleep(milliseconds: Expression)
}

enum Expression {
    case literal(AHKValue)
    case variable(String)
}
