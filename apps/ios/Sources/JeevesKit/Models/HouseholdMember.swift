//
//  HouseholdMember.swift
//  JeevesKit
//
//  Household member model representing a user's membership in a household
//

import Foundation

/// Household member model representing a user's membership in a household
public struct HouseholdMember: Codable, Identifiable, Sendable {
    public let id: LowercaseUUID
    public let userId: LowercaseUUID
    public let householdId: LowercaseUUID
    public let role: MemberRole
    public let joinedAt: Date

    public init(id: LowercaseUUID, userId: LowercaseUUID, householdId: LowercaseUUID, role: MemberRole, joinedAt: Date) {
        self.id = id
        self.userId = userId
        self.householdId = householdId
        self.role = role
        self.joinedAt = joinedAt
    }
}
