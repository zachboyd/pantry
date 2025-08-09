import Foundation

/// Represents an action that can be performed on a subject
public struct Action: Hashable, Sendable, ExpressibleByStringLiteral {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.lowercased())
    }
}

// Common CRUD actions
public extension Action {
    static let create: Action = "create"
    static let read: Action = "read"
    static let update: Action = "update"
    static let delete: Action = "delete"
    static let manage: Action = "manage" // Special action that includes all other actions
    static let all: Action = "all"       // Alias for manage
}

// String interpolation support
extension Action: CustomStringConvertible {
    public var description: String { value }
}

// Allow Action to be used in string comparisons
extension Action: Equatable {
    public static func == (lhs: Action, rhs: Action) -> Bool {
        lhs.value.lowercased() == rhs.value.lowercased()
    }
    
    public static func == (lhs: Action, rhs: String) -> Bool {
        lhs.value.lowercased() == rhs.lowercased()
    }
    
    public static func == (lhs: String, rhs: Action) -> Bool {
        lhs.lowercased() == rhs.value.lowercased()
    }
}