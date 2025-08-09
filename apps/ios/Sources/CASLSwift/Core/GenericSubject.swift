import Foundation

// MARK: - Generic Subject Implementation

/// A generic subject wrapper that can turn any type into a CASL Subject
/// This eliminates boilerplate for simple subject types
public struct GenericSubject<Properties: Sendable>: Subject, Sendable {
    public let properties: Properties
    private let _subjectType: SubjectType
    
    public static var subjectType: SubjectType {
        SubjectType(String(describing: Properties.self))
    }
    
    public var subjectType: SubjectType {
        _subjectType
    }
    
    /// Initialize with properties and an optional custom subject type
    public init(_ properties: Properties, subjectType: SubjectType? = nil) {
        self.properties = properties
        self._subjectType = subjectType ?? Self.subjectType
    }
    
    /// Initialize with properties using a string subject type
    public init(_ properties: Properties, subjectType: String) {
        self.properties = properties
        self._subjectType = SubjectType(subjectType)
    }
}

// MARK: - Identifiable Generic Subject

/// A generic subject that also conforms to IdentifiableSubject
public struct IdentifiableGenericSubject<ID: Hashable & Sendable, Properties: Sendable>: Subject, IdentifiableSubject, Sendable {
    public let id: ID
    public let properties: Properties
    private let _subjectType: SubjectType
    
    public static var subjectType: SubjectType {
        SubjectType(String(describing: Properties.self))
    }
    
    public var subjectType: SubjectType {
        _subjectType
    }
    
    /// Initialize with id and properties
    public init(id: ID, properties: Properties, subjectType: SubjectType? = nil) {
        self.id = id
        self.properties = properties
        self._subjectType = subjectType ?? Self.subjectType
    }
    
    /// Initialize with id and properties using a string subject type
    public init(id: ID, properties: Properties, subjectType: String) {
        self.id = id
        self.properties = properties
        self._subjectType = SubjectType(subjectType)
    }
}

// MARK: - Simple Subject

/// A minimal subject implementation with just a type and optional id
/// Note: This uses @unchecked Sendable due to the Any type in properties
public struct SimpleSubject: Subject, @unchecked Sendable {
    public let subjectType: SubjectType
    public let id: String?
    public let properties: [String: Any]?
    
    public static var subjectType: SubjectType {
        SubjectType("SimpleSubject")
    }
    
    public init(type: String, id: String? = nil, properties: [String: Any]? = nil) {
        self.subjectType = SubjectType(type)
        self.id = id
        self.properties = properties
    }
    
    public init(type: SubjectType, id: String? = nil, properties: [String: Any]? = nil) {
        self.subjectType = type
        self.id = id
        self.properties = properties
    }
}

// MARK: - Convenience Extensions

public extension GenericSubject {
    /// Access properties using dynamic member lookup (if Properties supports it)
    subscript<T>(dynamicMember keyPath: KeyPath<Properties, T>) -> T {
        properties[keyPath: keyPath]
    }
}

public extension IdentifiableGenericSubject {
    /// Access properties using dynamic member lookup (if Properties supports it)
    subscript<T>(dynamicMember keyPath: KeyPath<Properties, T>) -> T {
        properties[keyPath: keyPath]
    }
}

// MARK: - Type Aliases for Common Patterns

/// A generic subject with a String ID
public typealias StringIdentifiableSubject<Properties: Sendable> = IdentifiableGenericSubject<String, Properties>

/// A generic subject with a UUID ID
public typealias UUIDIdentifiableSubject<Properties: Sendable> = IdentifiableGenericSubject<UUID, Properties>

/// A generic subject with an Int ID
public typealias IntIdentifiableSubject<Properties: Sendable> = IdentifiableGenericSubject<Int, Properties>