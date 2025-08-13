//
//  MemberRole.swift
//  JeevesKit
//
//  Role enumeration for household members
//

import Foundation

/// Role of a member within a household
public enum MemberRole: String, Codable, CaseIterable, Sendable {
    case manager
    case member
    case ai

    /// Sort order for displaying members (manager first, then member, then ai)
    public var sortOrder: Int {
        switch self {
        case .manager: return 0
        case .member: return 1
        case .ai: return 2
        }
    }

    /// Whether this role has permission to manage household settings
    public var canManageHousehold: Bool {
        switch self {
        case .manager: return true
        case .member, .ai: return false
        }
    }

    /// Whether this role has permission to manage members
    public var canManageMembers: Bool {
        switch self {
        case .manager: return true
        case .member, .ai: return false
        }
    }
}
