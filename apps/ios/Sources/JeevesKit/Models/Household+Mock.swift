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
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "The Smith Family",
        description: "Our main family household for daily groceries and meal planning",
        createdBy: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        createdAt: Date().addingTimeInterval(-86400 * 30),
        updatedAt: Date().addingTimeInterval(-86400 * 2),
        memberCount: 4,
    )

    /// Secondary mock household for testing multiple households
    static let mock2 = Household(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "Beach House",
        description: "Weekend beach house for vacation planning",
        createdBy: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        createdAt: Date().addingTimeInterval(-86400 * 15),
        updatedAt: Date().addingTimeInterval(-86400 * 1),
        memberCount: 2,
    )

    /// Array of mock households for testing lists
    static let mockHouseholds = [mock, mock2]
}
