import Foundation

/// Represents the type of a subject in the permission system
public struct SubjectType: Hashable, Sendable, ExpressibleByStringLiteral {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    /// Create a SubjectType from a type
    public static func from<T>(_ type: T.Type) -> SubjectType {
        SubjectType(String(describing: type))
    }
}

// Common subject types for convenience
public extension SubjectType {
    static let all: SubjectType = "all"
    static let any: SubjectType = "any"
}

// String interpolation support
extension SubjectType: CustomStringConvertible {
    public var description: String { value }
}