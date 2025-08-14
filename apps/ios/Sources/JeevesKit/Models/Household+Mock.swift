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
        memberCount: 4,
    )

    /// Secondary mock household for testing multiple households
    static let mock2 = Household(
        id: "household_mock_2",
        name: "Beach House",
        description: "Weekend beach house for vacation planning",
        createdBy: "user_1",
        createdAt: Date().addingTimeInterval(-86400 * 15),
        updatedAt: Date().addingTimeInterval(-86400 * 1),
        memberCount: 2,
    )

    /// Array of mock households for testing lists
    static let mockHouseholds = [mock, mock2]
}
