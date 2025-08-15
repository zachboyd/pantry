//
//  UUIDExtensions.swift
//  JeevesKit
//
//  UUID conversion utilities for GraphQL integration
//

import Foundation

public extension UUID {
    /// Initialize a UUID from a String
    /// Returns nil if the string is not a valid UUID
    init?(uuidString: String?) {
        guard let uuidString else { return nil }
        self.init(uuidString: uuidString)
    }
}

public extension String {
    /// Convert String to UUID if valid
    var uuid: UUID? {
        UUID(uuidString: self)
    }
}

public extension String? {
    /// Convert optional String to optional UUID
    var uuid: UUID? {
        guard let self else { return nil }
        return UUID(uuidString: self)
    }
}

public extension UUID? {
    /// Convert optional UUID to optional String
    var uuidString: String? {
        self?.uuidString
    }
}
