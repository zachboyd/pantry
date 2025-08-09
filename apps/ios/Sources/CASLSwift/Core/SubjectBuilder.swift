import Foundation

// MARK: - Subject Builder

/// A builder for creating subjects with a fluent interface
@resultBuilder
public struct SubjectBuilder {
    public static func buildBlock<S: Subject>(_ subject: S) -> S {
        subject
    }
}

/// A fluent builder for creating custom subjects
public final class FluentSubjectBuilder<Properties: Sendable> {
    private var properties: Properties
    private var subjectType: SubjectType?
    
    public init(properties: Properties) {
        self.properties = properties
    }
    
    /// Set a custom subject type
    public func withType(_ type: String) -> Self {
        self.subjectType = SubjectType(type)
        return self
    }
    
    /// Set a custom subject type
    public func withType(_ type: SubjectType) -> Self {
        self.subjectType = type
        return self
    }
    
    /// Build a generic subject
    public func build() -> GenericSubject<Properties> {
        GenericSubject(properties, subjectType: subjectType)
    }
}

/// A fluent builder for creating identifiable subjects
public final class FluentIdentifiableSubjectBuilder<ID: Hashable & Sendable, Properties: Sendable> {
    private let id: ID
    private var properties: Properties
    private var subjectType: SubjectType?
    
    public init(id: ID, properties: Properties) {
        self.id = id
        self.properties = properties
    }
    
    /// Set a custom subject type
    public func withType(_ type: String) -> Self {
        self.subjectType = SubjectType(type)
        return self
    }
    
    /// Set a custom subject type
    public func withType(_ type: SubjectType) -> Self {
        self.subjectType = type
        return self
    }
    
    /// Build an identifiable generic subject
    public func build() -> IdentifiableGenericSubject<ID, Properties> {
        IdentifiableGenericSubject(id: id, properties: properties, subjectType: subjectType)
    }
}

// MARK: - Factory Methods

public struct SubjectFactory {
    
    /// Create a simple subject with just a type
    public static func simple(type: String) -> SimpleSubject {
        SimpleSubject(type: type)
    }
    
    /// Create a simple subject with type and id
    public static func simple(type: String, id: String) -> SimpleSubject {
        SimpleSubject(type: type, id: id)
    }
    
    /// Create a simple subject with type, id, and properties
    public static func simple(type: String, id: String? = nil, properties: [String: Any]) -> SimpleSubject {
        SimpleSubject(type: type, id: id, properties: properties)
    }
    
    /// Create a generic subject from any Sendable type
    public static func generic<T: Sendable>(_ value: T, type: String? = nil) -> GenericSubject<T> {
        if let type = type {
            return GenericSubject(value, subjectType: type)
        } else {
            return GenericSubject(value)
        }
    }
    
    /// Create an identifiable generic subject
    public static func identifiable<ID: Hashable & Sendable, T: Sendable>(
        id: ID,
        properties: T,
        type: String? = nil
    ) -> IdentifiableGenericSubject<ID, T> {
        if let type = type {
            return IdentifiableGenericSubject(id: id, properties: properties, subjectType: type)
        } else {
            return IdentifiableGenericSubject(id: id, properties: properties)
        }
    }
    
    /// Start building a fluent subject
    public static func build<T: Sendable>(_ properties: T) -> FluentSubjectBuilder<T> {
        FluentSubjectBuilder(properties: properties)
    }
    
    /// Start building a fluent identifiable subject
    public static func build<ID: Hashable & Sendable, T: Sendable>(
        id: ID,
        properties: T
    ) -> FluentIdentifiableSubjectBuilder<ID, T> {
        FluentIdentifiableSubjectBuilder(id: id, properties: properties)
    }
}

// MARK: - Property Wrapper for Subject Types

/// A property wrapper that automatically generates subject type from the wrapped type
@propertyWrapper
public struct SubjectTyped<Value> {
    public var wrappedValue: Value
    public let subjectType: SubjectType
    
    public init(wrappedValue: Value, type: String? = nil) {
        self.wrappedValue = wrappedValue
        self.subjectType = SubjectType(type ?? String(describing: Value.self))
    }
    
    public var projectedValue: SubjectType {
        subjectType
    }
}

// MARK: - Convenience Functions

/// Create a generic subject from any value
public func makeSubject<T: Sendable>(_ value: T, type: String? = nil) -> GenericSubject<T> {
    SubjectFactory.generic(value, type: type)
}

/// Create an identifiable subject
public func makeIdentifiableSubject<ID: Hashable & Sendable, T: Sendable>(
    id: ID,
    properties: T,
    type: String? = nil
) -> IdentifiableGenericSubject<ID, T> {
    SubjectFactory.identifiable(id: id, properties: properties, type: type)
}