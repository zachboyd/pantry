import Foundation

/// Protocol that marks an object as a subject that can have permissions checked against it
public protocol Subject: Sendable {
    /// The type identifier for this subject
    static var subjectType: SubjectType { get }
    
    /// Instance method to get the subject type (can be overridden for dynamic types)
    var subjectType: SubjectType { get }
}

// Default implementation
public extension Subject {
    var subjectType: SubjectType {
        Self.subjectType
    }
}

/// Protocol for subjects that can be identified
public protocol IdentifiableSubject: Subject {
    associatedtype ID: Hashable & Sendable
    var id: ID { get }
}

/// A type-erased wrapper for any Subject
public struct AnySubject: Subject, Sendable {
    public static let subjectType: SubjectType = "AnySubject"
    
    public let subjectType: SubjectType
    private let wrapped: any Subject
    
    public init<S: Subject>(_ subject: S) {
        self.wrapped = subject
        self.subjectType = subject.subjectType
    }
    
    /// Get the original wrapped subject if it matches the expected type
    public func `as`<S: Subject>(_ type: S.Type) -> S? {
        wrapped as? S
    }
}

/// A subject implementation for dictionary-based objects
public final class DictionarySubject: Subject, @unchecked Sendable {
    public static let subjectType: SubjectType = SubjectType("Dictionary")
    
    private let properties: [String: Any]
    
    public init(properties: [String: Any]) {
        self.properties = properties
    }
    
    /// Access property values
    public subscript(key: String) -> Any? {
        properties[key]
    }
}