/*
 AppSections.swift
 JeevesKit

 Centralized configuration for app sections (features) including icons, labels, and related settings
 */

import SwiftUI

/// Centralized configuration for app sections/features used throughout the app
public enum AppSections {
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
            L("tabs.pantry")
        case .chat:
            L("tabs.chat")
        case .lists:
            L("tabs.lists")
        case .settings:
            L("tabs.settings")
        case .profile:
            L("settings.profile")
        }
    }

    /// Get the SF Symbol icon name for a section (used everywhere - tabs, empty states, etc.)
    public static func icon(for section: Section) -> String {
        switch section {
        case .pantry:
            Icons.pantry
        case .chat:
            Icons.chat
        case .lists:
            Icons.lists
        case .settings:
            Icons.settings
        case .profile:
            Icons.profile
        }
    }

    /// Get whether the section icon has symbol variants (for tab bar selection)
    public static func hasSymbolVariant(for section: Section) -> Bool {
        switch section {
        case .chat, .lists, .settings:
            true
        case .pantry, .profile:
            false
        }
    }

    /// Get the accessibility identifier for a section
    public static func accessibilityIdentifier(for section: Section) -> String {
        switch section {
        case .pantry:
            AccessibilityUtilities.Identifier.pantryTab
        case .chat:
            AccessibilityUtilities.Identifier.chatTab
        case .lists:
            AccessibilityUtilities.Identifier.listsTab
        case .settings:
            AccessibilityUtilities.Identifier.settingsTab
        case .profile:
            "profileTab"
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
        icon(for: section)
    }

    /// Create an empty state configuration for a section
    @MainActor
    public static func emptyStateConfig(
        for section: Section,
        actionTitle: String? = nil,
        action: (@Sendable () -> Void)? = nil,
    ) -> EmptyStateConfig {
        switch section {
        case .pantry:
            EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("pantry.empty"),
                subtitle: L("pantry.empty_message"),
                actionTitle: actionTitle ?? L("pantry.add_first_item"),
                action: action,
            )
        case .chat:
            EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("chat.empty"),
                subtitle: L("chat.empty_message"),
                actionTitle: actionTitle ?? L("chat.send_message"),
                action: action,
            )
        case .lists:
            EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("lists.empty"),
                subtitle: L("lists.empty_message"),
                actionTitle: actionTitle ?? L("lists.create"),
                action: action,
            )
        case .settings:
            // Settings typically doesn't have an empty state
            EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("settings.title"),
                subtitle: "",
                actionTitle: nil,
                action: nil,
            )
        case .profile:
            // Profile typically doesn't have an empty state
            EmptyStateConfig(
                icon: emptyStateIcon(for: section),
                title: L("settings.profile"),
                subtitle: "",
                actionTitle: nil,
                action: nil,
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
            .pantry
        case .chat:
            .chat
        case .lists:
            .lists
        case .settings:
            .settings
        case .profile:
            .profile
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

public extension AppSections {
    /// Common household-related icons used throughout the app
    enum HouseholdIcons {
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
    static func householdEmptyStateConfig(
        icon: String = HouseholdIcons.noHousehold,
        titleKey: String,
        subtitleKey: String,
        actions: [EmptyStateAction] = [],
    ) -> EmptyStateConfig {
        EmptyStateConfig(
            icon: icon,
            title: L(titleKey),
            subtitle: L(subtitleKey),
            actions: actions,
        )
    }
}
