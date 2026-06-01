import Foundation

final class Environment {
    private var values: [String: AHKValue] = [:]

    func set(_ name: String, value: AHKValue) {
        values[name.lowercased()] = value
    }

    func get(_ name: String) -> AHKValue {
        values[name.lowercased()] ?? .empty
    }
}
