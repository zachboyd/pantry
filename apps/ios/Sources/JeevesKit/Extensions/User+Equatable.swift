//
//  User+Equatable.swift
//  JeevesKit
//
//  Extension to make User conform to Equatable
//

import Foundation

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id &&
            lhs.authUserId == rhs.authUserId &&
            lhs.email == rhs.email &&
            lhs.firstName == rhs.firstName &&
            lhs.lastName == rhs.lastName &&
            lhs.displayName == rhs.displayName &&
            lhs.avatarUrl == rhs.avatarUrl &&
            lhs.phone == rhs.phone &&
            lhs.birthDate == rhs.birthDate &&
            lhs.managedBy == rhs.managedBy &&
            lhs.relationshipToManager == rhs.relationshipToManager &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
    }
}
