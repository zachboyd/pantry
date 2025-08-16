//
//  LowercaseUUID.swift
//  JeevesKit
//
//  A UUID wrapper that ensures all string representations are lowercase.
//  This solves case sensitivity issues with database comparisons and ensures
//  consistent UUID handling throughout the application.
//

import Foundation

/// A UUID wrapper that ensures all string representations are lowercase.
/// This solves case sensitivity issues with database comparisons and ensures
/// consistent UUID handling throughout the application.
///
/// Use this type instead of raw UUID for all model properties.
public struct LowercaseUUID: Hashable, Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let uuid: UUID

    // MARK: - Initialization

    /// Creates a new UUID with lowercase string representation
    public init() {
        uuid = UUID()
    }

    /// Creates a LowercaseUUID from an existing UUID
    public init(from uuid: UUID) {
        self.uuid = uuid
    }

    /// Creates a LowercaseUUID from a string (case-insensitive)
    /// - Parameter uuidString: A string representation of a UUID (any case)
    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    // MARK: - Properties

    /// Always returns the UUID string in lowercase
    public var uuidString: String {
        uuid.uuidString.lowercased()
    }

    /// Returns the underlying UUID for compatibility with APIs that require it
    public var rawUUID: UUID {
        uuid
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuidString = try container.decode(String.self)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid UUID string: \(uuidString)",
            )
        }
        self.uuid = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uuidString)
    }

    // MARK: - Equatable

    public static func == (lhs: LowercaseUUID, rhs: LowercaseUUID) -> Bool {
        // UUIDs are compared by value, not by string representation
        lhs.uuid == rhs.uuid
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        uuidString
    }

    // MARK: - CustomDebugStringConvertible

    public var debugDescription: String {
        uuidString
    }
}

// MARK: - ExpressibleByStringLiteral

extension LowercaseUUID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let uuid = UUID(uuidString: value) else {
            fatalError("Invalid UUID string literal: \(value)")
        }
        self.uuid = uuid
    }
}

// MARK: - RawRepresentable

extension LowercaseUUID: RawRepresentable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        self.init(uuidString: rawValue)
    }

    public var rawValue: String {
        uuidString
    }
}

// MARK: - Comparable

extension LowercaseUUID: Comparable {
    public static func < (lhs: LowercaseUUID, rhs: LowercaseUUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

// MARK: - Convenience Extensions

public extension LowercaseUUID {
    /// Converts an optional UUID to an optional LowercaseUUID
    static func from(_ uuid: UUID?) -> LowercaseUUID? {
        guard let uuid else { return nil }
        return LowercaseUUID(from: uuid)
    }

    /// Converts an array of UUIDs to an array of LowercaseUUIDs
    static func from(_ uuids: [UUID]) -> [LowercaseUUID] {
        uuids.map { LowercaseUUID(from: $0) }
    }
}

// MARK: - UUID Extension

public extension UUID {
    /// Converts this UUID to a LowercaseUUID
    var lowercased: LowercaseUUID {
        LowercaseUUID(from: self)
    }
}
