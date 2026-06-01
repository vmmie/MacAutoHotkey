import Foundation

final class ExpressionParser {
    private let tokens: [ExpressionToken]
    private var index = 0

    init(source: String) throws {
        self.tokens = try ExpressionTokenizer(source: source).tokenize()
    }

    func parse() throws -> Expression {
        guard !tokens.isEmpty else {
            return .literal(.empty)
        }

        let expression = try parseOr()
        guard isAtEnd else {
            throw AHKError("Unexpected token '\(peek.lexeme)'.")
        }
        return expression
    }

    private func parseOr() throws -> Expression {
        var expression = try parseAnd()
        while matchOperator("||") {
            expression = .binary(left: expression, operator: .or, right: try parseAnd())
        }
        return expression
    }

    private func parseAnd() throws -> Expression {
        var expression = try parseComparison()
        while matchOperator("&&") {
            expression = .binary(left: expression, operator: .and, right: try parseComparison())
        }
        return expression
    }

    private func parseComparison() throws -> Expression {
        var expression = try parseTerm()
        while let op = matchAnyOperator(["=", "==", "!=", "<", "<=", ">", ">="]) {
            let binaryOperator: BinaryOperator = switch op {
            case "=", "==": .equal
            case "!=": .notEqual
            case "<": .lessThan
            case "<=": .lessThanOrEqual
            case ">": .greaterThan
            case ">=": .greaterThanOrEqual
            default: .equal
            }
            expression = .binary(left: expression, operator: binaryOperator, right: try parseTerm())
        }
        return expression
    }

    private func parseTerm() throws -> Expression {
        var expression = try parseFactor()
        while let op = matchAnyOperator(["+", "-", "."]) {
            let binaryOperator: BinaryOperator = switch op {
            case "+": .add
            case "-": .subtract
            case ".": .concatenate
            default: .add
            }
            expression = .binary(left: expression, operator: binaryOperator, right: try parseFactor())
        }
        return expression
    }

    private func parseFactor() throws -> Expression {
        var expression = try parseUnary()
        while let op = matchAnyOperator(["*", "/"]) {
            expression = .binary(
                left: expression,
                operator: op == "*" ? .multiply : .divide,
                right: try parseUnary()
            )
        }
        return expression
    }

    private func parseUnary() throws -> Expression {
        if matchOperator("!") {
            return .unary(operator: .not, expression: try parseUnary())
        }
        if matchOperator("-") {
            return .unary(operator: .negative, expression: try parseUnary())
        }
        return try parsePrimary()
    }

    private func parsePrimary() throws -> Expression {
        guard !isAtEnd else {
            throw AHKError("Expected expression.")
        }

        let token = advance()
        switch token.kind {
        case .string(let value):
            return .literal(.string(value))
        case .number(let value):
            return .literal(.number(value))
        case .identifier(let name):
            if name.caseInsensitiveCompare("true") == .orderedSame {
                return .literal(.boolean(true))
            }
            if name.caseInsensitiveCompare("false") == .orderedSame {
                return .literal(.boolean(false))
            }
            return .variable(name)
        case .leftParen:
            let expression = try parseOr()
            guard match(.rightParen) else {
                throw AHKError("Expected ')'.")
            }
            return expression
        case .rightParen, .operator:
            throw AHKError("Unexpected token '\(token.lexeme)'.")
        }
    }

    private var isAtEnd: Bool {
        index >= tokens.count
    }

    private var peek: ExpressionToken {
        tokens[index]
    }

    private func advance() -> ExpressionToken {
        let token = tokens[index]
        index += 1
        return token
    }

    private func match(_ kind: ExpressionTokenKind.Matcher) -> Bool {
        guard !isAtEnd, kind.matches(tokens[index].kind) else {
            return false
        }
        index += 1
        return true
    }

    private func matchOperator(_ op: String) -> Bool {
        guard !isAtEnd, case .operator(let value) = tokens[index].kind, value == op else {
            return false
        }
        index += 1
        return true
    }

    private func matchAnyOperator(_ ops: Set<String>) -> String? {
        guard !isAtEnd, case .operator(let value) = tokens[index].kind, ops.contains(value) else {
            return nil
        }
        index += 1
        return value
    }
}

private struct ExpressionTokenizer {
    let source: String

    func tokenize() throws -> [ExpressionToken] {
        var tokens: [ExpressionToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let char = source[index]

            if char.isWhitespace {
                source.formIndex(after: &index)
                continue
            }

            if char == "\"" {
                tokens.append(try readString(startingAt: &index))
                continue
            }

            if char.isNumber {
                tokens.append(readNumber(startingAt: &index))
                continue
            }

            if char.isLetter || char == "_" {
                tokens.append(readIdentifier(startingAt: &index))
                continue
            }

            if char == "(" {
                tokens.append(ExpressionToken(kind: .leftParen, lexeme: "("))
                source.formIndex(after: &index)
                continue
            }

            if char == ")" {
                tokens.append(ExpressionToken(kind: .rightParen, lexeme: ")"))
                source.formIndex(after: &index)
                continue
            }

            if let op = readOperator(startingAt: &index) {
                tokens.append(ExpressionToken(kind: .operator(op), lexeme: op))
                continue
            }

            throw AHKError("Unexpected character '\(char)'.")
        }

        return tokens
    }

    private func readString(startingAt index: inout String.Index) throws -> ExpressionToken {
        source.formIndex(after: &index)
        var value = ""
        var previous: Character?

        while index < source.endIndex {
            let char = source[index]
            source.formIndex(after: &index)

            if char == "\"" && previous != "`" {
                return ExpressionToken(kind: .string(unescapeString(value)), lexeme: "\"\(value)\"")
            }

            value.append(char)
            previous = char
        }

        throw AHKError("Unterminated string literal.")
    }

    private func readNumber(startingAt index: inout String.Index) -> ExpressionToken {
        let start = index
        var sawDot = false

        while index < source.endIndex {
            let char = source[index]
            if char == ".", !sawDot {
                sawDot = true
                source.formIndex(after: &index)
                continue
            }
            guard char.isNumber else {
                break
            }
            source.formIndex(after: &index)
        }

        let lexeme = String(source[start..<index])
        return ExpressionToken(kind: .number(Double(lexeme) ?? 0), lexeme: lexeme)
    }

    private func readIdentifier(startingAt index: inout String.Index) -> ExpressionToken {
        let start = index
        while index < source.endIndex {
            let char = source[index]
            guard char.isLetter || char.isNumber || char == "_" else {
                break
            }
            source.formIndex(after: &index)
        }
        let lexeme = String(source[start..<index])
        return ExpressionToken(kind: .identifier(lexeme), lexeme: lexeme)
    }

    private func readOperator(startingAt index: inout String.Index) -> String? {
        let twoCharacterOps = ["==", "!=", "<=", ">=", "&&", "||"]
        if let next = source.index(index, offsetBy: 2, limitedBy: source.endIndex) {
            let candidate = String(source[index..<next])
            if twoCharacterOps.contains(candidate) {
                index = next
                return candidate
            }
        }

        let char = source[index]
        let oneCharacterOps: Set<Character> = ["+", "-", "*", "/", ".", "=", "<", ">", "!"]
        guard oneCharacterOps.contains(char) else {
            return nil
        }
        source.formIndex(after: &index)
        return String(char)
    }

    private func unescapeString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "``", with: "`")
            .replacingOccurrences(of: "`n", with: "\n")
            .replacingOccurrences(of: "`t", with: "\t")
            .replacingOccurrences(of: "`\"", with: "\"")
    }
}

private struct ExpressionToken {
    var kind: ExpressionTokenKind
    var lexeme: String
}

private enum ExpressionTokenKind {
    case string(String)
    case number(Double)
    case identifier(String)
    case `operator`(String)
    case leftParen
    case rightParen

    enum Matcher {
        case rightParen

        func matches(_ kind: ExpressionTokenKind) -> Bool {
            return switch (self, kind) {
            case (.rightParen, .rightParen):
                true
            default:
                false
            }
        }
    }
}
