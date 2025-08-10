/*
 ThemeManager.swift
 JeevesKit

 Centralized theme management with persistence and SwiftUI integration
 Similar to the travel app's UserPreferencesManager but focused on theme functionality
 */

import Foundation
import SwiftUI

/// Centralized theme management with persistence
@Observable @MainActor
public final class ThemeManager: Sendable {
    private nonisolated(unsafe) static var _shared: ThemeManager?

    public nonisolated static var shared: ThemeManager {
        if let existing = _shared {
            return existing
        }
        let instance = MainActor.assumeIsolated {
            ThemeManager()
        }
        _shared = instance
        return instance
    }

    // MARK: - Properties

    public private(set) var currentTheme: ThemePreference = .system
    public private(set) var userSavedTheme: ThemePreference? = nil

    /// Returns the SwiftUI ColorScheme for the current theme
    public var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system:
            return nil // Let system decide
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    // MARK: - Private Properties

    private static let themeKey = "app_theme"
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSavedTheme()
    }

    // MARK: - Public Methods

    /// Load theme from UserDefaults
    private func loadSavedTheme() {
        let savedThemeRawValue = userDefaults.string(forKey: Self.themeKey)
        let savedTheme = savedThemeRawValue.flatMap(ThemePreference.init(rawValue:)) ?? .system

        userSavedTheme = savedTheme
        currentTheme = savedTheme
    }

    /// Save theme to UserDefaults
    private func saveTheme(_ theme: ThemePreference) {
        userDefaults.set(theme.rawValue, forKey: Self.themeKey)
    }

    /// Update theme temporarily (for preview)
    public func updateTheme(_ theme: ThemePreference) {
        currentTheme = theme
    }

    /// Set and save theme preference
    public func setUserSavedTheme(_ theme: ThemePreference) {
        userSavedTheme = theme
        saveTheme(theme)
        updateTheme(theme)
    }

    /// Clear saved theme and reset to system
    public func clearSavedTheme() {
        userDefaults.removeObject(forKey: Self.themeKey)
        userSavedTheme = nil
        currentTheme = .system
    }
}

// MARK: - ThemePreference Extensions

public extension ThemePreference {
    @MainActor
    var displayName: String {
        switch self {
        case .system: return L("settings.appearance.theme.system")
        case .light: return L("settings.appearance.theme.light")
        case .dark: return L("settings.appearance.theme.dark")
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .system: return L("settings.appearance.theme.system.description")
        case .light: return L("settings.appearance.theme.light.description")
        case .dark: return L("settings.appearance.theme.dark.description")
        }
    }

    var iconName: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var color: Color {
        switch self {
        case .system: return DesignTokens.Colors.Text.secondary
        case .light: return .orange
        case .dark: return .indigo
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
