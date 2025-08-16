//
//  UUIDExtensions.swift
//  JeevesKit
//
//  UUID and LowercaseUUID conversion utilities for GraphQL integration
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
    /// Convert String to LowercaseUUID if valid
    var lowercaseUUID: LowercaseUUID? {
        LowercaseUUID(uuidString: self)
    }

    /// Convert String to UUID if valid (deprecated - use lowercaseUUID)
    @available(*, deprecated, message: "Use lowercaseUUID instead")
    var uuid: UUID? {
        UUID(uuidString: self)
    }
}

public extension String? {
    /// Convert optional String to optional LowercaseUUID
    var lowercaseUUID: LowercaseUUID? {
        guard let self else { return nil }
        return LowercaseUUID(uuidString: self)
    }

    /// Convert optional String to optional UUID (deprecated - use lowercaseUUID)
    @available(*, deprecated, message: "Use lowercaseUUID instead")
    var uuid: UUID? {
        guard let self else { return nil }
        return UUID(uuidString: self)
    }
}

public extension LowercaseUUID? {
    /// Convert optional LowercaseUUID to optional String
    var uuidString: String? {
        self?.uuidString
    }
}
