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
        case .manager: 0
        case .member: 1
        case .ai: 2
        }
    }

    /// Whether this role has permission to manage household settings
    public var canManageHousehold: Bool {
        switch self {
        case .manager: true
        case .member, .ai: false
        }
    }

    /// Whether this role has permission to manage members
    public var canManageMembers: Bool {
        switch self {
        case .manager: true
        case .member, .ai: false
        }
    }
}
