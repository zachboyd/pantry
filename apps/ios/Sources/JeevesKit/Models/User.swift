//
//  User.swift
//  JeevesKit
//
//  User model representing an authenticated user
//

import Foundation

/// User model representing an authenticated user
public struct User: Identifiable, Sendable {
    public let id: LowercaseUUID
    public let authUserId: String?
    public let email: String?
    public let firstName: String
    public let lastName: String
    public let displayName: String?
    public let avatarUrl: String?
    public let phone: String?
    public let birthDate: String?
    public let managedBy: LowercaseUUID?
    public let relationshipToManager: String?
    public let primaryHouseholdId: LowercaseUUID?
    public let isAi: Bool
    public let createdAt: String
    public let updatedAt: String

    /// Computed property to match the old User struct interface
    public var name: String? {
        displayName ?? "\(firstName) \(lastName)"
    }

    /// Computed property to get email as non-optional (for compatibility)
    public var emailOrEmpty: String {
        email ?? ""
    }

    /// Computed property to convert createdAt to Date
    public var createdAtDate: Date {
        DateUtilities.dateFromGraphQLOrNow(createdAt)
    }

    /// Computed property to get user initials for avatar display
    public var initials: String {
        if !firstName.isEmpty || !lastName.isEmpty {
            let firstInitial = firstName.first.map(String.init) ?? ""
            let lastInitial = lastName.first.map(String.init) ?? ""
            let result = firstInitial + lastInitial
            return result.isEmpty ? "U" : result.uppercased()
        } else if let displayName, !displayName.isEmpty {
            let components = displayName.split(separator: " ")
            if components.count >= 2 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            } else if let first = components.first {
                return String(first.prefix(2)).uppercased()
            }
        } else if let email, !email.isEmpty {
            return String(email.prefix(2)).uppercased()
        }
        return "U"
    }

    /// Compatibility initializer for the old User struct interface
    public init(id: LowercaseUUID, email: String, name: String?, createdAt: Date) {
        self.id = id
        authUserId = nil
        self.email = email
        // Parse first and last name from full name
        let nameParts = (name ?? "").split(separator: " ", maxSplits: 1)
        firstName = String(nameParts.first ?? "")
        lastName = nameParts.count > 1 ? String(nameParts[1]) : ""
        displayName = name
        avatarUrl = nil
        phone = nil
        birthDate = nil
        managedBy = nil
        relationshipToManager = nil
        primaryHouseholdId = nil
        isAi = false
        self.createdAt = DateUtilities.graphQLStringFromDate(createdAt)
        updatedAt = DateUtilities.graphQLStringFromDate(createdAt)
    }

    public init(
        id: LowercaseUUID,
        authUserId: String?,
        email: String?,
        firstName: String,
        lastName: String,
        displayName: String?,
        avatarUrl: String?,
        phone: String?,
        birthDate: String?,
        managedBy: LowercaseUUID?,
        relationshipToManager: String?,
        primaryHouseholdId: LowercaseUUID?,
        isAi: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.authUserId = authUserId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phone = phone
        self.birthDate = birthDate
        self.managedBy = managedBy
        self.relationshipToManager = relationshipToManager
        self.primaryHouseholdId = primaryHouseholdId
        self.isAi = isAi
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
