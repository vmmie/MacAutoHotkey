import Foundation

final class ScriptParser {
    private let fileName: String
    private var lines: [SourceLine]
    private var index = 0

    init(source: String, fileName: String = "<memory>") {
        self.fileName = fileName
        self.lines = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { SourceLine(number: $0.offset + 1, text: String($0.element)) }
    }

    func parse() throws -> AHKScript {
        var topLevelActions: [Action] = []
        var hotkeys: [HotkeyDeclaration] = []
        var hotstrings: [HotstringDeclaration] = []

        while let line = nextMeaningfulLine() {
            if isDirective(line.text) {
                continue
            }

            if let hotstring = try parseHotstring(line) {
                hotstrings.append(hotstring)
                continue
            }

            if let hotkey = try parseHotkey(line) {
                hotkeys.append(hotkey)
                continue
            }

            topLevelActions.append(try parseAction(line.text, lineNumber: line.number))
        }

        return AHKScript(topLevelActions: topLevelActions, hotkeys: hotkeys, hotstrings: hotstrings)
    }

    private func nextMeaningfulLine() -> SourceLine? {
        while index < lines.count {
            let line = lines[index]
            index += 1
            let trimmed = stripComment(line.text).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return SourceLine(number: line.number, text: trimmed)
            }
        }
        return nil
    }

    private func parseHotkey(_ line: SourceLine) throws -> HotkeyDeclaration? {
        guard let range = line.text.range(of: "::") else {
            return nil
        }

        let lhs = String(line.text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard HotkeyCombo.looksLikeHotkey(lhs) else {
            return nil
        }

        let combo = try HotkeyCombo.parse(lhs)
        let rhs = String(line.text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let actions: [Action]
        if rhs.isEmpty {
            actions = try parseBlockActions(startingAt: line.number)
        } else {
            actions = [try parseAction(rhs, lineNumber: line.number)]
        }
        return HotkeyDeclaration(combo: combo, actions: actions, sourceLine: line.number)
    }

    private func parseHotstring(_ line: SourceLine) throws -> HotstringDeclaration? {
        guard line.text.hasPrefix("::") else {
            return nil
        }

        let parts = line.text.split(separator: "::", omittingEmptySubsequences: false)
        guard parts.count >= 3 else {
            return nil
        }

        let trigger = String(parts[1])
        let replacement = parts.dropFirst(2).joined(separator: "::")
        guard !trigger.isEmpty else {
            throw parseError("Hotstring trigger cannot be empty.", line: line.number)
        }

        return HotstringDeclaration(trigger: trigger, replacement: replacement, sourceLine: line.number)
    }

    private func parseBlockActions(startingAt lineNumber: Int) throws -> [Action] {
        var actions: [Action] = []
        var sawBrace = false

        while let line = nextMeaningfulLine() {
            if line.text == "{" {
                sawBrace = true
                continue
            }
            if line.text == "}" || line.text.caseInsensitiveCompare("Return") == .orderedSame {
                return actions
            }
            if HotkeyCombo.lineStartsWithHotkey(line.text) || line.text.hasPrefix("::") {
                index -= 1
                if sawBrace {
                    throw parseError("Missing closing } for hotkey block.", line: lineNumber)
                }
                return actions
            }
            actions.append(try parseAction(line.text, lineNumber: line.number))
        }

        return actions
    }

    private func parseAction(_ text: String, lineNumber: Int) throws -> Action {
        if text.caseInsensitiveCompare("if") == .orderedSame || text.lowercased().hasPrefix("if ") {
            let conditionText = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            guard !conditionText.isEmpty else {
                throw parseError("If expects a condition.", line: lineNumber)
            }
            return .ifBlock(
                condition: try parseExpression(conditionText, lineNumber: lineNumber),
                actions: try parseActionBody(startingAt: lineNumber)
            )
        }

        if text.caseInsensitiveCompare("loop") == .orderedSame || text.lowercased().hasPrefix("loop ") {
            let countText = String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            guard !countText.isEmpty else {
                throw parseError("Loop currently expects an iteration count.", line: lineNumber)
            }
            return .loop(
                count: try parseExpression(countText, lineNumber: lineNumber),
                actions: try parseActionBody(startingAt: lineNumber)
            )
        }

        if let assignment = text.range(of: ":=") {
            let name = String(text[..<assignment.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard isIdentifier(name) else {
                throw parseError("Invalid assignment target '\(name)'.", line: lineNumber)
            }
            let expression = try parseExpression(String(text[assignment.upperBound...]), lineNumber: lineNumber)
            return .assign(name: name, expression: expression)
        }

        let call = splitFunctionLikeCommand(text)
        switch call.name.lowercased() {
        case "msgbox":
            return .msgBox(try parseExpression(call.arguments.joined(separator: " "), lineNumber: lineNumber))
        case "send":
            return .send(try parseExpression(call.arguments.joined(separator: " "), lineNumber: lineNumber))
        case "mousemove":
            guard call.arguments.count >= 2 else {
                throw parseError("MouseMove expects x and y.", line: lineNumber)
            }
            return .mouseMove(
                x: try parseExpression(call.arguments[0], lineNumber: lineNumber),
                y: try parseExpression(call.arguments[1], lineNumber: lineNumber)
            )
        case "click":
            if call.arguments.isEmpty {
                return .click(x: nil, y: nil)
            }
            guard call.arguments.count >= 2 else {
                throw parseError("Click expects either no arguments or x and y.", line: lineNumber)
            }
            return .click(
                x: try parseExpression(call.arguments[0], lineNumber: lineNumber),
                y: try parseExpression(call.arguments[1], lineNumber: lineNumber)
            )
        case "sleep":
            guard let first = call.arguments.first else {
                throw parseError("Sleep expects milliseconds.", line: lineNumber)
            }
            return .sleep(milliseconds: try parseExpression(first, lineNumber: lineNumber))
        default:
            throw parseError("Unsupported statement '\(text)'.", line: lineNumber)
        }
    }

    private func parseExpression(_ raw: String, lineNumber: Int) throws -> Expression {
        do {
            return try ExpressionParser(source: raw).parse()
        } catch let error as AHKError {
            throw parseError(error.message, line: lineNumber)
        } catch {
            throw parseError("Unsupported expression '\(raw.trimmingCharacters(in: .whitespaces))'.", line: lineNumber)
        }
    }

    private func parseActionBody(startingAt lineNumber: Int) throws -> [Action] {
        guard let line = nextMeaningfulLine() else {
            throw parseError("Expected action body.", line: lineNumber)
        }

        if line.text == "{" {
            return try parseBracedActions(startingAt: lineNumber)
        }

        if line.text == "}" {
            throw parseError("Unexpected }.", line: line.number)
        }

        return [try parseAction(line.text, lineNumber: line.number)]
    }

    private func parseBracedActions(startingAt lineNumber: Int) throws -> [Action] {
        var actions: [Action] = []

        while let line = nextMeaningfulLine() {
            if line.text == "}" {
                return actions
            }
            actions.append(try parseAction(line.text, lineNumber: line.number))
        }

        throw parseError("Missing closing }.", line: lineNumber)
    }

    private func splitFunctionLikeCommand(_ text: String) -> (name: String, arguments: [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") {
            let name = String(trimmed[..<open]).trimmingCharacters(in: .whitespaces)
            let inside = String(trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)])
            return (name, splitArguments(inside))
        }

        let pieces = trimmed.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
        let name = pieces.first.map(String.init) ?? trimmed
        let rest = pieces.count > 1 ? String(pieces[1]) : ""
        return (name, rest.isEmpty ? [] : splitArguments(rest))
    }

    private func splitArguments(_ text: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inString = false
        var previous: Character?

        for char in text {
            if char == "\"" && previous != "`" {
                inString.toggle()
            }
            if char == "," && !inString {
                args.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            previous = char
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(current.trimmingCharacters(in: .whitespaces))
        }
        return args
    }

    private func stripComment(_ text: String) -> String {
        var result = ""
        var inString = false
        var previous: Character?

        for char in text {
            if char == "\"" && previous != "`" {
                inString.toggle()
            }
            if char == ";" && !inString {
                break
            }
            result.append(char)
            previous = char
        }
        return result
    }

    private func unescapeString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "``", with: "`")
            .replacingOccurrences(of: "`n", with: "\n")
            .replacingOccurrences(of: "`t", with: "\t")
            .replacingOccurrences(of: "`\"", with: "\"")
    }

    private func isDirective(_ text: String) -> Bool {
        text.hasPrefix("#")
    }

    private func isIdentifier(_ text: String) -> Bool {
        guard let first = text.first, first.isLetter || first == "_" else {
            return false
        }
        return text.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func parseError(_ message: String, line: Int) -> AHKError {
        AHKError("\(fileName):\(line): \(message)")
    }
}

private struct SourceLine {
    var number: Int
    var text: String
}
