//
//  HouseholdMember+Equatable.swift
//  PantryKit
//
//  Extension to make HouseholdMember conform to Equatable
//

import Foundation

extension HouseholdMember: Equatable {
    public static func == (lhs: HouseholdMember, rhs: HouseholdMember) -> Bool {
        lhs.id == rhs.id &&
        lhs.userId == rhs.userId &&
        lhs.householdId == rhs.householdId &&
        lhs.role == rhs.role &&
        lhs.joinedAt == rhs.joinedAt
    }
}