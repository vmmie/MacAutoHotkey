import Foundation

enum AHKValue: Equatable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case empty

    var description: String {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            value.rounded() == value ? String(Int(value)) : String(value)
        case .boolean(let value):
            value ? "true" : "false"
        case .empty:
            ""
        }
    }

    var numberValue: Double? {
        switch self {
        case .number(let value):
            value
        case .string(let value):
            Double(value)
        case .boolean(let value):
            value ? 1 : 0
        case .empty:
            nil
        }
    }

    var booleanValue: Bool {
        switch self {
        case .boolean(let value):
            value
        case .number(let value):
            value != 0
        case .string(let value):
            !value.isEmpty && value != "0"
        case .empty:
            false
        }
    }
}
