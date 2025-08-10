//
//  Household+Mock.swift
//  JeevesKit
//
//  Mock data extensions for Household
//

import Foundation

public extension Household {
    /// Centralized mock household for testing and previews
    static let mock = Household(
        id: "household_mock_1",
        name: "The Smith Family",
        description: "Our main family household for daily groceries and meal planning",
        createdBy: "user_1",
        createdAt: Date().addingTimeInterval(-86400 * 30),
        updatedAt: Date().addingTimeInterval(-86400 * 2),
        members: [
            HouseholdMember(id: "member_1", userId: "user_1", householdId: "household_mock_1", role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 30)),
            HouseholdMember(id: "member_2", userId: "user_2", householdId: "household_mock_1", role: .admin, joinedAt: Date().addingTimeInterval(-86400 * 20)),
            HouseholdMember(id: "member_3", userId: "user_3", householdId: "household_mock_1", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 10)),
            HouseholdMember(id: "member_4", userId: "user_4", householdId: "household_mock_1", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 5)),
        ]
    )

    /// Secondary mock household for testing multiple households
    static let mock2 = Household(
        id: "household_mock_2",
        name: "Beach House",
        description: "Weekend beach house for vacation planning",
        createdBy: "user_1",
        createdAt: Date().addingTimeInterval(-86400 * 15),
        updatedAt: Date().addingTimeInterval(-86400 * 1),
        members: [
            HouseholdMember(id: "member_5", userId: "user_1", householdId: "household_mock_2", role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 15)),
            HouseholdMember(id: "member_6", userId: "user_5", householdId: "household_mock_2", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 7)),
        ]
    )

    /// Array of mock households for testing lists
    static let mockHouseholds = [mock, mock2]
}
