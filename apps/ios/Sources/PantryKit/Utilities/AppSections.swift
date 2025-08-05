/*
 AppSections.swift
 PantryKit

 Centralized configuration for app sections (features) including icons, labels, and related settings
 */

import SwiftUI

/// Centralized configuration for app sections/features used throughout the app
public struct AppSections {
    
    /// Section identifiers for the main features of the app
    public enum Section: String, CaseIterable {
        case pantry
        case chat
        case lists
        case settings
        case profile // iPad only
    }
    
    // MARK: - Private Icon Definitions (Single Source of Truth)
    
    /// Single source of truth for all section icons
    /// To change any section's icon, update it here and it will be used everywhere
    private enum Icons {
        static let pantry = "archivebox"
        static let chat = "message"
        static let lists = "list.bullet.clipboard"
        static let settings = "gearshape"
        static let profile = "person.circle"
    }
    
    /// Get the localized label for a section
    @MainActor
    public static func label(for section: Section) -> String {
        switch section {
        case .pantry:
            return L("tabs.pantry")
        case .chat:
            return L("tabs.chat")
        case .lists:
            return L("tabs.lists")
        case .settings:
            return L("tabs.settings")
        case .profile:
            return L("settings.profile")
        }
    }
    
    /// Get the SF Symbol icon name for a section (used everywhere - tabs, empty states, etc.)
    public static func icon(for section: Section) -> String {
        switch section {
        case .pantry:
            return Icons.pantry
        case .chat:
            return Icons.chat
        case .lists:
            return Icons.lists
        case .settings:
            return Icons.settings
        case .profile:
            return Icons.profile
        }
    }
    
    /// Get whether the section icon has symbol variants (for tab bar selection)
    public static func hasSymbolVariant(for section: Section) -> Bool {
        switch section {
        case .chat, .lists, .settings:
            return true
        case .pantry, .profile:
            return false
        }
    }
    
    /// Get the accessibility identifier for a section
    public static func accessibilityIdentifier(for section: Section) -> String {
        switch section {
        case .pantry:
            return AccessibilityUtilities.Identifier.pantryTab
        case .chat:
            return AccessibilityUtilities.Identifier.chatTab
        case .lists:
            return AccessibilityUtilities.Identifier.listsTab
        case .settings:
            return AccessibilityUtilities.Identifier.settingsTab
        case .profile:
            return "profileTab"
        }
    }
    
    /// Get the Label view for a section (combines icon and text)
    @MainActor
    public static func makeLabel(for section: Section) -> some View {
        Label(label(for: section), systemImage: icon(for: section))
    }
    
    /// Get just the icon view for a section
    public static func makeIcon(for section: Section, color: Color? = nil) -> some View {
        Image(systemName: icon(for: section))
            .foregroundColor(color ?? DesignTokens.Colors.Primary.base)
    }
    
    /// Get the icon to use in empty states (same as section icon for consistency)
    public static func emptyStateIcon(for section: Section) -> String {
        // Returns the same icon as used everywhere for complete consistency
        return icon(for: section)
    }
    
    /// Create an empty state configuration for a section
    @MainActor
    public static func emptyStateConfig(
        for section: Section,
        actionTitle: String? = nil,
        action: (@Sendable () -> Void)? = nil
    ) -> EmptyStateConfig {
        switch section {
        case .pantry:
            return EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("pantry.empty"),
                subtitle: L("pantry.empty_message"),
                actionTitle: actionTitle ?? L("pantry.add_first_item"),
                action: action
            )
        case .chat:
            return EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("chat.empty"),
                subtitle: L("chat.empty_message"),
                actionTitle: actionTitle ?? L("chat.send_message"),
                action: action
            )
        case .lists:
            return EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("lists.empty"),
                subtitle: L("lists.empty_message"),
                actionTitle: actionTitle ?? L("lists.create"),
                action: action
            )
        case .settings:
            // Settings typically doesn't have an empty state
            return EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("settings.title"),
                subtitle: "",
                actionTitle: nil,
                action: nil
            )
        case .profile:
            // Profile typically doesn't have an empty state
            return EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("settings.profile"),
                subtitle: "",
                actionTitle: nil,
                action: nil
            )
        }
    }
}

// MARK: - Convenience Extensions

extension AppSections.Section {
    /// Convert from MainTab enum (for backward compatibility)
    init?(from mainTab: MainTab) {
        switch mainTab {
        case .pantry:
            self = .pantry
        case .chat:
            self = .chat
        case .lists:
            self = .lists
        case .settings:
            self = .settings
        case .profile:
            self = .profile
        }
    }
    
    /// Convert to MainTab enum (for backward compatibility)
    var toMainTab: MainTab? {
        switch self {
        case .pantry:
            return .pantry
        case .chat:
            return .chat
        case .lists:
            return .lists
        case .settings:
            return .settings
        case .profile:
            return .profile
        }
    }
}

// MARK: - MainTab Extension for Direct Access

extension MainTab {
    /// Get the corresponding AppSections.Section
    var appSection: AppSections.Section {
        // This conversion is guaranteed to succeed because both enums have identical cases
        AppSections.Section(from: self)!
    }
}

// MARK: - Household Utilities

extension AppSections {
    /// Common household-related icons used throughout the app
    public enum HouseholdIcons {
        /// Icon for household (general)
        public static let household = "house.circle"
        
        /// Icon for household members
        public static let members = "person.2.circle"
        
        /// Icon for household settings
        public static let settings = "gearshape.circle"
        
        /// Icon for creating a household
        public static let create = "plus.circle"
        
        /// Icon for joining a household
        public static let join = "arrow.right.circle"
        
        /// Icon for household switcher
        public static let switcher = "arrow.left.arrow.right.circle"
        
        /// Icon for invite/share
        public static let invite = "square.and.arrow.up"
        
        /// Icon for no household state
        public static let noHousehold = "house.circle"
    }
    
    /// Create an empty state configuration for household-related states
    @MainActor
    public static func householdEmptyStateConfig(
        icon: String = HouseholdIcons.noHousehold,
        titleKey: String,
        subtitleKey: String,
        actions: [EmptyStateAction] = []
    ) -> EmptyStateConfig {
        EmptyStateConfig(
            icon: icon,
            title: L(titleKey),
            subtitle: L(subtitleKey),
            actions: actions
        )
    }
}