import Foundation

/// Errors that can occur during permission encoding/decoding
public enum PermissionError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case invalidAction(String)
    case invalidSubject(String)
    case invalidConditions
    case unsupportedVersion(String)
    case encodingFailed(Error)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case let .missingRequiredField(field):
            return "Missing required field: \(field)"
        case let .invalidAction(action):
            return "Invalid action: \(action)"
        case let .invalidSubject(subject):
            return "Invalid subject: \(subject)"
        case .invalidConditions:
            return "Invalid conditions format"
        case let .unsupportedVersion(version):
            return "Unsupported permission format version: \(version)"
        case let .encodingFailed(error):
            return "Failed to encode permissions: \(error.localizedDescription)"
        case let .decodingFailed(error):
            return "Failed to decode permissions: \(error.localizedDescription)"
        }
    }
}

/// Handles encoding and decoding of permissions
public enum PermissionCoder {
    /// Supported format versions
    public static let supportedVersions = ["1.0"]

    /// Current format version
    public static let currentVersion = "1.0"

    /// JSON encoder configured for permissions
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// JSON decoder configured for permissions
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Encoding

    /// Encode a single rule to JSON data
    public static func encode(rule: Rule) throws -> Data {
        do {
            return try encoder.encode(rule.toPermission())
        } catch {
            throw PermissionError.encodingFailed(error)
        }
    }

    /// Encode multiple rules to JSON data
    public static func encode(rules: [Rule]) throws -> Data {
        do {
            let permissions = rules.map { $0.toPermission() }
            return try encoder.encode(permissions)
        } catch {
            throw PermissionError.encodingFailed(error)
        }
    }

    /// Encode rules as a PermissionSet with metadata
    public static func encode(
        rules: [Rule],
        version: String = currentVersion,
        metadata: [String: Any]? = nil
    ) throws -> Data {
        do {
            let permissions = rules.map { $0.toPermission() }
            let codableMetadata = metadata?.compactMapValues { AnyCodable($0) }
            let permissionSet = PermissionSet(
                version: version,
                permissions: permissions,
                metadata: codableMetadata
            )
            return try encoder.encode(permissionSet)
        } catch {
            throw PermissionError.encodingFailed(error)
        }
    }

    // MARK: - Decoding

    /// Decode a single permission from JSON data
    public static func decodePermission(from data: Data) throws -> Permission {
        do {
            let permission = try decoder.decode(Permission.self, from: data)
            try validatePermission(permission)
            return permission
        } catch let error as PermissionError {
            throw error
        } catch {
            throw PermissionError.decodingFailed(error)
        }
    }

    /// Decode multiple permissions from JSON data
    public static func decodePermissions(from data: Data) throws -> [Permission] {
        do {
            // Try to decode as array of Permission objects first
            if let permissions = try? decoder.decode([Permission].self, from: data) {
                try permissions.forEach(validatePermission)
                return permissions
            }

            // Try to decode as CASL array format [[action, subject, conditions?], ...]
            if let caslArrayFormat = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
                let permissions = try caslArrayFormat.map { item -> Permission in
                    guard item.count >= 2 else {
                        throw PermissionError.invalidJSON
                    }

                    // First element is the action
                    guard let actionString = item[0] as? String else {
                        throw PermissionError.invalidAction("")
                    }
                    let action = StringOrArray(actionString)

                    // Second element is the subject
                    guard let subjectString = item[1] as? String else {
                        throw PermissionError.invalidSubject("")
                    }
                    let subject = StringOrArray(subjectString)

                    // Third element is conditions (optional)
                    var conditions: [String: AnyCodable]?
                    if item.count > 2, let conditionsDict = item[2] as? [String: Any] {
                        conditions = conditionsDict.mapValues { AnyCodable($0) }
                    }

                    return Permission(
                        action: action,
                        subject: subject,
                        conditions: conditions
                    )
                }

                try permissions.forEach(validatePermission)
                return permissions
            }

            // Try to decode as PermissionSet
            if let permissionSet = try? decoder.decode(PermissionSet.self, from: data) {
                try validateVersion(permissionSet.version)
                try permissionSet.permissions.forEach(validatePermission)
                return permissionSet.permissions
            }

            // Try to decode as single permission
            let permission = try decoder.decode(Permission.self, from: data)
            try validatePermission(permission)
            return [permission]

        } catch let error as PermissionError {
            throw error
        } catch {
            throw PermissionError.decodingFailed(error)
        }
    }

    /// Decode a PermissionSet from JSON data
    public static func decodePermissionSet(from data: Data) throws -> PermissionSet {
        do {
            let permissionSet = try decoder.decode(PermissionSet.self, from: data)
            try validateVersion(permissionSet.version)
            try permissionSet.permissions.forEach(validatePermission)
            return permissionSet
        } catch let error as PermissionError {
            throw error
        } catch {
            throw PermissionError.decodingFailed(error)
        }
    }

    /// Decode rules from JSON data
    /// Note: A single permission with multiple actions/subjects will expand to multiple rules
    public static func decodeRules(from data: Data) throws -> [Rule] {
        let permissions = try decodePermissions(from: data)
        return permissions.flatMap { $0.toRules() }
    }

    // MARK: - Validation

    /// Validate a permission has required fields and valid values
    private static func validatePermission(_ permission: Permission) throws {
        // Validate action exists and is not empty
        if permission.action.values.isEmpty {
            throw PermissionError.invalidAction("")
        }

        // Validate each action is not empty
        for action in permission.action.values {
            if action.isEmpty {
                throw PermissionError.invalidAction(action)
            }
        }

        // Subject is optional in CASL (for claim-based rules)
        // But if provided, validate it's not empty
        if let subject = permission.subject {
            for subjectValue in subject.values {
                if subjectValue.isEmpty {
                    throw PermissionError.invalidSubject(subjectValue)
                }
            }
        }

        // Additional validation could be added here
        // For example, checking against known actions/subjects
    }

    /// Validate format version is supported
    private static func validateVersion(_ version: String) throws {
        if !supportedVersions.contains(version) {
            throw PermissionError.unsupportedVersion(version)
        }
    }

    // MARK: - Convenience Methods

    /// Encode rules to JSON string
    public static func encodeToString(rules: [Rule]) throws -> String {
        let data = try encode(rules: rules)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PermissionError.encodingFailed(NSError(
                domain: "CASLSwift",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to UTF-8 string"]
            ))
        }
        return string
    }

    /// Decode rules from JSON string
    public static func decodeRules(from string: String) throws -> [Rule] {
        guard let data = string.data(using: .utf8) else {
            throw PermissionError.invalidJSON
        }
        return try decodeRules(from: data)
    }
}
