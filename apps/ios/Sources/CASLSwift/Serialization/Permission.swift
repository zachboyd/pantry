import Foundation

/// Represents a permission in JSON format matching CASL's RawRule structure
/// This is the exact structure used by CASL for importing/exporting permissions
public struct Permission: Codable, Sendable {
    /// The action allowed/denied (e.g., "read", "update", "delete", "manage")
    /// Can be a single action or an array of actions
    public let action: StringOrArray
    
    /// The subject type this permission applies to (e.g., "Article", "Post", "all")
    /// Optional for claim-based rules, can be a single subject or an array
    public let subject: StringOrArray?
    
    /// Optional conditions that must be met for the permission to apply
    /// These are MongoDB-style conditions (e.g., {"ownerId": "${userId}"})
    public let conditions: [String: AnyCodable]?
    
    /// Whether this permission is inverted (deny instead of allow)
    /// Defaults to false (allow)
    public let inverted: Bool?
    
    /// Optional fields this permission applies to
    /// Can be a single field or an array of fields
    public let fields: StringOrArray?
    
    /// Optional reason for this permission (useful for debugging and audit trails)
    public let reason: String?
    
    /// CodingKeys for JSON encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case action
        case subject
        case conditions
        case inverted
        case fields
        case reason
    }
    
    // MARK: - Custom Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        action = try container.decode(StringOrArray.self, forKey: .action)
        subject = try container.decodeIfPresent(StringOrArray.self, forKey: .subject)
        conditions = try container.decodeIfPresent([String: AnyCodable].self, forKey: .conditions)
        inverted = try container.decodeIfPresent(Bool.self, forKey: .inverted)
        fields = try container.decodeIfPresent(StringOrArray.self, forKey: .fields)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(action, forKey: .action)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encodeIfPresent(conditions, forKey: .conditions)
        
        // Only encode inverted if it's true (CASL convention)
        if inverted == true {
            try container.encode(inverted, forKey: .inverted)
        }
        
        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
    
    public init(
        action: StringOrArray,
        subject: StringOrArray? = nil,
        conditions: [String: AnyCodable]? = nil,
        inverted: Bool? = nil,
        fields: StringOrArray? = nil,
        reason: String? = nil
    ) {
        self.action = action
        self.subject = subject
        self.conditions = conditions
        self.inverted = inverted
        self.fields = fields
        self.reason = reason
    }
}

/// A collection of permissions with optional metadata
public struct PermissionSet: Codable, Sendable {
    /// Version of the permission format
    public let version: String
    
    /// Array of permissions
    public let permissions: [Permission]
    
    /// Optional metadata
    public let metadata: [String: AnyCodable]?
    
    public init(
        version: String = "1.0",
        permissions: [Permission],
        metadata: [String: AnyCodable]? = nil
    ) {
        self.version = version
        self.permissions = permissions
        self.metadata = metadata
    }
}

/// Type-erased Codable container
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// Extension to make AnyCodable Sendable
extension AnyCodable: @unchecked Sendable {}

// Convenience extensions for converting between Permission and Rule
extension Permission {
    /// Convert Permission to Rule
    /// Note: CASL supports multiple actions/subjects per rule in JSON,
    /// but our Rule struct only supports single values, so we take the first
    public func toRule() -> Rule {
        let conditions: Conditions? = self.conditions.map { conditionsDict in
            let data = conditionsDict.mapValues { $0.value }
            return Conditions(data)
        }
        
        // Get the first action (or default to "read" if somehow empty)
        let actionValue = action.first ?? "read"
        
        // Get the first subject (or default to "all" for claim-based rules)
        let subjectValue = subject?.first ?? "all"
        
        // Convert fields from StringOrArray to [String]?
        let fieldArray: [String]? = fields?.values.isEmpty == false ? fields?.values : nil
        
        return Rule(
            action: Action(actionValue),
            subject: SubjectType(subjectValue),
            conditions: conditions,
            inverted: inverted ?? false,
            fields: fieldArray,
            reason: reason,
            priority: 0  // Priority is not part of CASL's JSON format
        )
    }
    
    /// Convert Permission to multiple Rules if it has multiple actions/subjects
    public func toRules() -> [Rule] {
        let conditions: Conditions? = self.conditions.map { conditionsDict in
            let data = conditionsDict.mapValues { $0.value }
            return Conditions(data)
        }
        
        let actions = action.values
        let subjects = subject?.values ?? ["all"]
        let fieldArray: [String]? = fields?.values.isEmpty == false ? fields?.values : nil
        
        // Create a rule for each combination of action and subject
        var rules: [Rule] = []
        for actionValue in actions {
            for subjectValue in subjects {
                let rule = Rule(
                    action: Action(actionValue),
                    subject: SubjectType(subjectValue),
                    conditions: conditions,
                    inverted: inverted ?? false,
                    fields: fieldArray,
                    reason: reason,
                    priority: 0
                )
                rules.append(rule)
            }
        }
        
        return rules
    }
}

extension Rule {
    /// Convert Rule to Permission
    public func toPermission() -> Permission {
        let conditions: [String: AnyCodable]? = self.conditions.map { cond in
            cond.data.mapValues { AnyCodable($0) }
        }
        
        // Convert single values to StringOrArray
        let actionValue = StringOrArray(action.value)
        let subjectValue = subject.value == "all" ? nil : StringOrArray(subject.value)
        let fieldsValue: StringOrArray? = fields.map { StringOrArray($0) }
        
        return Permission(
            action: actionValue,
            subject: subjectValue,
            conditions: conditions,
            inverted: inverted ? true : nil,  // Only include if true
            fields: fieldsValue,
            reason: reason
            // Note: priority is NOT included as it's not part of CASL's JSON format
        )
    }
}