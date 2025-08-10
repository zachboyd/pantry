import Foundation

// MARK: - Action Codable

extension Action: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - SubjectType Codable

extension SubjectType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - AnySendable Codable

extension AnySendable: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnySendable].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnySendable].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnySendable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .dictionary(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Conditions Codable

extension Conditions: Codable {
    private enum CodingKeys: String, CodingKey {
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnySendable].self)
        self.init(sendable: dict)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(sendableData)
    }
}

// MARK: - Rule Codable

extension Rule: Codable {
    private enum CodingKeys: String, CodingKey {
        case action
        case subject
        case conditions
        case inverted
        case fields
        case reason
        case priority
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        action = try container.decode(Action.self, forKey: .action)
        subject = try container.decode(SubjectType.self, forKey: .subject)
        conditions = try container.decodeIfPresent(Conditions.self, forKey: .conditions)
        inverted = try container.decodeIfPresent(Bool.self, forKey: .inverted) ?? false
        fields = try container.decodeIfPresent([String].self, forKey: .fields)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(action, forKey: .action)
        try container.encode(subject, forKey: .subject)
        try container.encodeIfPresent(conditions, forKey: .conditions)

        // Only encode inverted if it's true
        if inverted {
            try container.encode(inverted, forKey: .inverted)
        }

        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encodeIfPresent(reason, forKey: .reason)

        // Only encode priority if it's not 0
        if priority != 0 {
            try container.encode(priority, forKey: .priority)
        }
    }
}
