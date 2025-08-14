/*
 Accessibility.swift
 JeevesKit

 Accessibility utilities and extensions
 */

import SwiftUI

/// Accessibility utilities for Jeeves app
public enum AccessibilityUtilities {
    /// Standard accessibility identifiers
    public enum Identifier {
        // Authentication
        public static let signInButton = "sign_in_button"
        public static let signUpButton = "sign_up_button"
        public static let emailField = "email_field"
        public static let passwordField = "password_field"

        // Navigation
        public static let pantryTab = "pantry_tab"
        public static let chatTab = "chat_tab"
        public static let listsTab = "lists_tab"
        public static let settingsTab = "settings_tab"

        // Household
        public static let householdSwitcher = "household_switcher"
        public static let createHouseholdButton = "create_household_button"
        public static let joinHouseholdButton = "join_household_button"

        // Actions
        public static let addButton = "add_button"
        public static let editButton = "edit_button"
        public static let deleteButton = "delete_button"
        public static let saveButton = "save_button"
        public static let cancelButton = "cancel_button"
    }

    /// Semantic accessibility labels
    public enum Label {
        public static let loading = "Loading content"
        public static let error = "Error occurred"
        public static let empty = "No content available"
        public static let household = "Current household"
        public static let member = "Household member"
        public static let organizer = "Household organizer"
    }

    /// Accessibility hints for complex interactions
    public enum Hint {
        public static let householdSwitcher = "Double tap to switch between households"
        public static let addIngredient = "Double tap to add a new ingredient to your pantry"
        public static let sendMessage = "Double tap to send a message to household members"
        public static let createList = "Double tap to create a new list"
    }
}

/// View modifier for common accessibility patterns
public struct AccessibilityHelper: ViewModifier {
    let label: String?
    let hint: String?
    let identifier: String?
    let traits: AccessibilityTraits

    public init(
        label: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.identifier = identifier
        self.traits = traits
    }

    public func body(content: Content) -> some View {
        content
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityAddTraits(traits)
    }
}

public extension View {
    /// Apply accessibility enhancements
    func accessibility(
        label: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: AccessibilityTraits = [],
    ) -> some View {
        modifier(AccessibilityHelper(
            label: label,
            hint: hint,
            identifier: identifier,
            traits: traits,
        ))
    }

    /// Mark as a button for accessibility
    func accessibilityButton(
        label: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
    ) -> some View {
        accessibility(
            label: label,
            hint: hint,
            identifier: identifier,
            traits: .isButton,
        )
    }

    /// Mark as a header for accessibility
    func accessibilityHeader(
        label: String? = nil,
        identifier: String? = nil,
    ) -> some View {
        accessibility(
            label: label,
            identifier: identifier,
            traits: .isHeader,
        )
    }
}

/// Accessibility-focused dynamic type support
public extension Font {
    /// Body text that scales with accessibility text sizes
    static var accessibleBody: Font {
        .system(.body, design: .default)
    }

    /// Caption text that scales with accessibility text sizes
    static var accessibleCaption: Font {
        .system(.caption, design: .default)
    }

    /// Headline text that scales with accessibility text sizes
    static var accessibleHeadline: Font {
        .system(.headline, design: .default)
    }
}

/// Color contrast utilities for accessibility
public extension Color {
    /// Ensure proper contrast for text on background
    static func contrastText(on _: Color) -> Color {
        // Simplified contrast calculation - in production, use proper contrast algorithms
        .primary
    }

    /// High contrast color for important elements
    static var highContrast: Color {
        .primary
    }
}
