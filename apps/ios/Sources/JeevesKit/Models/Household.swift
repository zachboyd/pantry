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

    // Client-side only properties
    public var members: [HouseholdMember] = [] // Loaded separately via householdMembers query

    /// Computed property for member count
    public var memberCount: Int {
        members.count
    }

    /// Determines if the current user is the owner of this household
    /// Note: For now, we'll assume the first member with owner role is the current user
    /// In a real app, this would check against the authenticated user's ID
    public var isCurrentUserOwner: Bool {
        // For mock data, assume the owner is always the current user for the first household
        return members.contains { $0.role == .owner && $0.userId == "user_1" }
    }

    public init(id: String, name: String, description: String?, createdBy: String, createdAt: Date, updatedAt: Date, members: [HouseholdMember] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.members = members
    }
}
