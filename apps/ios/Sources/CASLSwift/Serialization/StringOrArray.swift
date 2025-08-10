import Foundation

/// Represents a value that can be either a single string or an array of strings
/// This matches CASL's flexible format for actions, subjects, and fields
public enum StringOrArray: Codable, Sendable {
    case single(String)
    case array([String])

    /// Get all string values as an array
    public var values: [String] {
        switch self {
        case let .single(value):
            return [value]
        case let .array(values):
            return values
        }
    }

    /// Get the first value (useful for conversion)
    public var first: String? {
        switch self {
        case let .single(value):
            return value
        case let .array(values):
            return values.first
        }
    }

    /// Check if this represents a single value
    public var isSingle: Bool {
        switch self {
        case .single:
            return true
        case .array:
            return false
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let single = try? container.decode(String.self) {
            self = .single(single)
        } else if let array = try? container.decode([String].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(
                StringOrArray.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [String]"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .single(value):
            try container.encode(value)
        case let .array(values):
            try container.encode(values)
        }
    }
}

// MARK: - Convenience Initializers

public extension StringOrArray {
    /// Initialize from a single string
    init(_ string: String) {
        self = .single(string)
    }

    /// Initialize from an array of strings
    init(_ array: [String]) {
        self = .array(array)
    }

    /// Initialize from an optional array (nil becomes empty array)
    init(array: [String]?) {
        if let array = array, !array.isEmpty {
            self = .array(array)
        } else {
            self = .array([])
        }
    }
}

// MARK: - Equatable

extension StringOrArray: Equatable {
    public static func == (lhs: StringOrArray, rhs: StringOrArray) -> Bool {
        switch (lhs, rhs) {
        case let (.single(l), .single(r)):
            return l == r
        case let (.array(l), .array(r)):
            return l == r
        case let (.single(l), .array(r)):
            return r.count == 1 && r.first == l
        case let (.array(l), .single(r)):
            return l.count == 1 && l.first == r
        }
    }
}
