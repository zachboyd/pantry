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
    case householdDetails(householdId: UUID)
    case householdEdit(householdId: UUID)
    case householdMembers(householdId: UUID)
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
            true
        case (.onboarding, .onboarding):
            true
        case (.householdCreation, .householdCreation):
            true
        case (.householdJoin, .householdJoin):
            true
        case let (.householdDetails(lhsId), .householdDetails(rhsId)):
            lhsId == rhsId
        case let (.householdEdit(lhsId), .householdEdit(rhsId)):
            lhsId == rhsId
        case let (.householdMembers(lhsId), .householdMembers(rhsId)):
            lhsId == rhsId
        case (.householdSwitcher, .householdSwitcher):
            true
        case (.pantryTab, .pantryTab):
            true
        case (.chatTab, .chatTab):
            true
        case (.listsTab, .listsTab):
            true
        case (.settingsTab, .settingsTab):
            true
        case (.userProfile, .userProfile):
            true
        case (.appearanceSettings, .appearanceSettings):
            true
        default:
            false
        }
    }
}

// MARK: - Navigation Utilities

public extension NavigationDestination {
    /// Human-readable title for the destination (useful for analytics/debugging)
    var title: String {
        switch self {
        case .authentication:
            "Sign In"
        case .onboarding:
            "Welcome"
        case .householdCreation:
            "Create Household"
        case .householdJoin:
            "Join Household"
        case .householdDetails:
            "Household Details"
        case .householdEdit:
            "Edit Household"
        case .householdMembers:
            "Household Members"
        case .householdSwitcher:
            "Switch Household"
        case .pantryTab:
            "Pantry"
        case .chatTab:
            "Chat"
        case .listsTab:
            "Lists"
        case .settingsTab:
            "Settings"
        case .userProfile:
            "Profile"
        case .appearanceSettings:
            "Appearance"
        }
    }

    /// Whether this destination requires authentication
    var requiresAuth: Bool {
        switch self {
        case .authentication, .onboarding:
            false
        default:
            true
        }
    }

    /// Whether this destination requires a household context
    var requiresHousehold: Bool {
        switch self {
        case .authentication, .onboarding, .householdCreation, .householdJoin, .householdSwitcher:
            false
        default:
            true
        }
    }

    /// Tab bar icon name for tab destinations
    var tabIconName: String? {
        switch self {
        case .pantryTab:
            AppSections.icon(for: .pantry)
        case .chatTab:
            AppSections.icon(for: .chat)
        case .listsTab:
            AppSections.icon(for: .lists)
        case .settingsTab:
            AppSections.icon(for: .settings)
        default:
            nil
        }
    }
}
