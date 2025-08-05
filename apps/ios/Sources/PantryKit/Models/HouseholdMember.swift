//
//  HouseholdMember.swift
//  PantryKit
//
//  Household member model representing a user's membership in a household
//

import Foundation

/// Household member model representing a user's membership in a household
public struct HouseholdMember: Codable, Identifiable, Sendable {
    public let id: String
    public let userId: String
    public let householdId: String
    public let role: MemberRole
    public let joinedAt: Date

    public init(id: String, userId: String, householdId: String, role: MemberRole, joinedAt: Date) {
        self.id = id
        self.userId = userId
        self.householdId = householdId
        self.role = role
        self.joinedAt = joinedAt
    }
}
