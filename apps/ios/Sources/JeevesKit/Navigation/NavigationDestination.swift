/*
 NavigationDestination.swift
 JeevesKit

 Type-safe navigation destinations for SwiftUI 6 NavigationPath integration
 Follows Apple's recommended navigation patterns for structured, testable routing
 */

import Foundation

/// Type-safe navigation destinations for the Jeeves app
/// Supports NavigationPath for programmatic navigation and deep linking
public enum NavigationDestination: Hashable, Codable, Sendable {
    // MARK: - Authentication Navigation

    case authentication
    case onboarding

    // MARK: - Household Navigation

    case householdCreation
    case householdJoin
    case householdDetails(householdId: String)
    case householdEdit(householdId: String)
    case householdMembers(householdId: String)
    case householdSwitcher

    // MARK: - Main App Navigation

    case pantryTab
    case chatTab
    case listsTab
    case settingsTab

    // MARK: - Profile Navigation

    case userProfile
    case appearanceSettings

    // MARK: - Hashable Implementation

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .authentication:
            hasher.combine("authentication")
        case .onboarding:
            hasher.combine("onboarding")
        case .householdCreation:
            hasher.combine("householdCreation")
        case .householdJoin:
            hasher.combine("householdJoin")
        case let .householdDetails(householdId):
            hasher.combine("householdDetails")
            hasher.combine(householdId)
        case let .householdEdit(householdId):
            hasher.combine("householdEdit")
            hasher.combine(householdId)
        case let .householdMembers(householdId):
            hasher.combine("householdMembers")
            hasher.combine(householdId)
        case .householdSwitcher:
            hasher.combine("householdSwitcher")
        case .pantryTab:
            hasher.combine("pantryTab")
        case .chatTab:
            hasher.combine("chatTab")
        case .listsTab:
            hasher.combine("listsTab")
        case .settingsTab:
            hasher.combine("settingsTab")
        case .userProfile:
            hasher.combine("userProfile")
        case .appearanceSettings:
            hasher.combine("appearanceSettings")
        }
    }

    // MARK: - Equatable Implementation

    public static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.authentication, .authentication):
            return true
        case (.onboarding, .onboarding):
            return true
        case (.householdCreation, .householdCreation):
            return true
        case (.householdJoin, .householdJoin):
            return true
        case let (.householdDetails(lhsId), .householdDetails(rhsId)):
            return lhsId == rhsId
        case let (.householdEdit(lhsId), .householdEdit(rhsId)):
            return lhsId == rhsId
        case let (.householdMembers(lhsId), .householdMembers(rhsId)):
            return lhsId == rhsId
        case (.householdSwitcher, .householdSwitcher):
            return true
        case (.pantryTab, .pantryTab):
            return true
        case (.chatTab, .chatTab):
            return true
        case (.listsTab, .listsTab):
            return true
        case (.settingsTab, .settingsTab):
            return true
        case (.userProfile, .userProfile):
            return true
        case (.appearanceSettings, .appearanceSettings):
            return true
        default:
            return false
        }
    }
}

// MARK: - Navigation Utilities

public extension NavigationDestination {
    /// Human-readable title for the destination (useful for analytics/debugging)
    var title: String {
        switch self {
        case .authentication:
            return "Sign In"
        case .onboarding:
            return "Welcome"
        case .householdCreation:
            return "Create Household"
        case .householdJoin:
            return "Join Household"
        case .householdDetails:
            return "Household Details"
        case .householdEdit:
            return "Edit Household"
        case .householdMembers:
            return "Household Members"
        case .householdSwitcher:
            return "Switch Household"
        case .pantryTab:
            return "Pantry"
        case .chatTab:
            return "Chat"
        case .listsTab:
            return "Lists"
        case .settingsTab:
            return "Settings"
        case .userProfile:
            return "Profile"
        case .appearanceSettings:
            return "Appearance"
        }
    }

    /// Whether this destination requires authentication
    var requiresAuth: Bool {
        switch self {
        case .authentication, .onboarding:
            return false
        default:
            return true
        }
    }

    /// Whether this destination requires a household context
    var requiresHousehold: Bool {
        switch self {
        case .authentication, .onboarding, .householdCreation, .householdJoin, .householdSwitcher:
            return false
        default:
            return true
        }
    }

    /// Tab bar icon name for tab destinations
    var tabIconName: String? {
        switch self {
        case .pantryTab:
            return AppSections.icon(for: .pantry)
        case .chatTab:
            return AppSections.icon(for: .chat)
        case .listsTab:
            return AppSections.icon(for: .lists)
        case .settingsTab:
            return AppSections.icon(for: .settings)
        default:
            return nil
        }
    }
}
