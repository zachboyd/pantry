//
//  Household.swift
//  JeevesKit
//
//  Household model representing a group of users
//

import Foundation

/// Household model representing a group of users
public struct Household: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdBy: String
    public let createdAt: Date
    public let updatedAt: Date

    // Member count from GraphQL
    public let memberCount: Int

    /// Determines if the current user is the owner of this household
    /// Note: This would need to be determined from the current user's role in the household
    /// For now, this returns false as we don't have member data loaded
    public var isCurrentUserOwner: Bool {
        // TODO: This should be determined from the authenticated user's role
        // Would need to fetch members separately or include user's role in the household query
        false
    }

    public init(id: String, name: String, description: String?, createdBy: String, createdAt: Date, updatedAt: Date, memberCount: Int = 0) {
        self.id = id
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.memberCount = memberCount
    }
}
