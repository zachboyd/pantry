import Foundation

/// Default subject type detector that uses reflection and type names
public struct DefaultSubjectTypeDetector: SubjectTypeDetector {
    /// Custom type mappings
    private let typeMappings: [String: SubjectType]

    /// Whether to use simple type names (without module prefix)
    private let useSimpleNames: Bool

    public init(
        typeMappings: [String: SubjectType] = [:],
        useSimpleNames: Bool = true
    ) {
        self.typeMappings = typeMappings
        self.useSimpleNames = useSimpleNames
    }

    public func detectSubjectType(of object: Any) -> SubjectType? {
        // First check if object conforms to Subject protocol
        if let subject = object as? Subject {
            return subject.subjectType
        }

        // Get the type name
        let typeName = String(describing: type(of: object))

        // Check custom mappings first
        if let mappedType = typeMappings[typeName] {
            return mappedType
        }

        // Extract simple name if needed
        let subjectTypeName: String
        if useSimpleNames {
            // Remove module prefix (e.g., "MyApp.User" -> "User")
            subjectTypeName = typeName.split(separator: ".").last.map(String.init) ?? typeName
        } else {
            subjectTypeName = typeName
        }

        return SubjectType(subjectTypeName)
    }
}

/// Subject type detector that uses a key path to extract the type
public struct KeyPathSubjectTypeDetector<Root>: SubjectTypeDetector {
    /// Function to extract subject type from root
    private let extractor: @Sendable (Root) -> String

    /// Fallback detector if extraction fails
    private let fallback: SubjectTypeDetector?

    // Note: KeyPath-based init removed due to Sendable constraints
    // Use the extractor-based init instead

    public init(
        extractor: @escaping @Sendable (Root) -> String,
        fallback: SubjectTypeDetector? = nil
    ) {
        self.extractor = extractor
        self.fallback = fallback
    }

    public func detectSubjectType(of object: Any) -> SubjectType? {
        // Try to cast to the expected root type
        if let root = object as? Root {
            let typeName = extractor(root)
            return SubjectType(typeName)
        }

        // Fall back to other detector if available
        return fallback?.detectSubjectType(of: object)
    }
}

/// Composite subject type detector that tries multiple detectors in order
public struct CompositeSubjectTypeDetector: SubjectTypeDetector {
    /// Detectors to try in order
    private let detectors: [SubjectTypeDetector]

    public init(detectors: [SubjectTypeDetector]) {
        self.detectors = detectors
    }

    public func detectSubjectType(of object: Any) -> SubjectType? {
        for detector in detectors {
            if let subjectType = detector.detectSubjectType(of: object) {
                return subjectType
            }
        }
        return nil
    }
}

/// Protocol-based subject type detector
public struct ProtocolBasedSubjectTypeDetector: SubjectTypeDetector {
    /// Protocol to subject type mappings
    private let protocolMappings: [(check: @Sendable (Any) -> Bool, subjectType: SubjectType)]

    /// Fallback detector
    private let fallback: SubjectTypeDetector?

    public init(fallback: SubjectTypeDetector? = nil) {
        protocolMappings = []
        self.fallback = fallback
    }

    /// Create detector with protocol mappings
    public init(
        mappings: [(typePattern: String, SubjectType)],
        fallback: SubjectTypeDetector? = nil
    ) {
        protocolMappings = mappings.map { typePattern, subjectType in
            let check: @Sendable (Any) -> Bool = { object in
                // Check if the object's type name contains the pattern
                String(describing: type(of: object)).contains(typePattern)
            }
            return (check, subjectType)
        }
        self.fallback = fallback
    }

    /// Create detector with custom checks
    public init(
        checks: [(@Sendable (Any) -> Bool, SubjectType)],
        fallback: SubjectTypeDetector? = nil
    ) {
        protocolMappings = checks.map { check, subjectType in
            (check: check, subjectType: subjectType)
        }
        self.fallback = fallback
    }

    public func detectSubjectType(of object: Any) -> SubjectType? {
        // Check protocol mappings
        for (check, subjectType) in protocolMappings {
            if check(object) {
                return subjectType
            }
        }

        // Fall back
        return fallback?.detectSubjectType(of: object)
    }
}

// MARK: - Utility Functions

/// Global function to detect subject type using default detector
public func detectSubjectType(of object: Any) -> SubjectType {
    let detector = DefaultSubjectTypeDetector()
    return detector.detectSubjectType(of: object) ?? SubjectType("Unknown")
}

// MARK: - Subject Extensions

public extension Subject {
    /// Create a subject type from this subject's type
    static func subjectType() -> SubjectType {
        SubjectType.from(Self.self)
    }
}
