//
//  MemberRole.swift
//  JeevesKit
//
//  Role enumeration for household members
//

import Foundation

/// Role of a member within a household
public enum MemberRole: String, Codable, CaseIterable, Sendable {
    case owner
    case admin
    case member

    /// Sort order for displaying members (owner first, then admin, then member)
    public var sortOrder: Int {
        switch self {
        case .owner: return 0
        case .admin: return 1
        case .member: return 2
        }
    }

    /// Whether this role has permission to manage household settings
    public var canManageHousehold: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }

    /// Whether this role has permission to manage members
    public var canManageMembers: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }
}
