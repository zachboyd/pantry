import Foundation

/// Represents conditions that must be met for a rule to apply
public struct Conditions: Sendable {
    /// The raw condition data stored as sendable values
    let sendableData: [String: AnySendable]

    /// Access the raw data (computed property for compatibility)
    public var data: [String: Any] {
        sendableData.reduce(into: [:]) { result, item in
            result[item.key] = item.value.value
        }
    }

    public init(_ data: [String: Any]) {
        sendableData = data.compactMapValues { AnySendable($0) }
    }

    /// Initialize with sendable data
    public init(sendable: [String: AnySendable]) {
        sendableData = sendable
    }

    /// Empty conditions (always matches)
    public static let empty = Conditions(sendable: [:])

    /// Check if conditions are empty
    public var isEmpty: Bool {
        sendableData.isEmpty
    }
}

// Extension for sendable conversion
public extension Conditions {
    /// Convert to sendable dictionary
    var sendable: [String: AnySendable] {
        sendableData
    }
}

/// A type-erased sendable value wrapper
public enum AnySendable: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnySendable])
    case dictionary([String: AnySendable])
    case null

    /// Get the underlying value
    public var value: Any {
        switch self {
        case let .string(value): return value
        case let .int(value): return value
        case let .double(value): return value
        case let .bool(value): return value
        case let .array(value): return value.map { $0.value }
        case let .dictionary(value): return value.mapValues { $0.value }
        case .null: return NSNull()
        }
    }

    public init?(_ value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            let sendableArray = array.compactMap { AnySendable($0) }
            guard sendableArray.count == array.count else { return nil }
            self = .array(sendableArray)
        case let dict as [String: Any]:
            let sendableDict = dict.compactMapValues { AnySendable($0) }
            guard sendableDict.count == dict.count else { return nil }
            self = .dictionary(sendableDict)
        case is NSNull:
            self = .null
        default:
            return nil
        }
    }
}

/// Condition operators for MongoDB-style queries
public enum ConditionOperator: String, Sendable {
    case eq = "$eq" // equals
    case ne = "$ne" // not equals
    case gt = "$gt" // greater than
    case gte = "$gte" // greater than or equal
    case lt = "$lt" // less than
    case lte = "$lte" // less than or equal
    case `in` = "$in" // in array
    case nin = "$nin" // not in array
    case exists = "$exists" // field exists
    case regex = "$regex" // regex match

    // Logical operators
    case and = "$and"
    case or = "$or"
    case not = "$not"
}
