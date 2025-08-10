/*
 UserPreferencesService.swift
 JeevesKit

 User preferences service implementation.
 Handles app settings, notification preferences, and user state management.
 */

import Foundation

/// User preferences service implementation
@MainActor
public final class UserPreferencesService: UserPreferencesServiceProtocol {
    private static let logger = Logger(category: "UserPreferencesService")

    // MARK: - Properties

    private let authService: any AuthServiceProtocol
    private let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let notificationSettings = "pantry.notifications"
        static let appSettings = "pantry.app_settings"
        static let lastSelectedHousehold = "pantry.last_household"
        static let themePreference = "pantry.theme"
        static let userPreferencesVersion = "pantry.preferences_version"
    }

    private let currentPreferencesVersion = 1

    // MARK: - Initialization

    public init(
        authService: any AuthServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.userDefaults = userDefaults
        Self.logger.info("⚙️ UserPreferencesService initialized")

        // Check and migrate preferences if needed
        Task {
            await migratePreferencesIfNeeded()
        }
    }

    // MARK: - UserPreferencesServiceProtocol Implementation

    /// Get notification settings
    public func getNotificationSettings() async throws -> NotificationSettings {
        Self.logger.info("🔔 Getting notification settings")

        guard let data = userDefaults.data(forKey: Keys.notificationSettings) else {
            Self.logger.info("📝 No notification settings found, returning defaults")
            return NotificationSettings()
        }

        do {
            let settings = try JSONDecoder().decode(NotificationSettings.self, from: data)
            Self.logger.info("✅ Retrieved notification settings")
            return settings
        } catch {
            Self.logger.warning("⚠️ Failed to decode notification settings, returning defaults: \(error)")
            return NotificationSettings()
        }
    }

    /// Update notification settings
    public func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        Self.logger.info("🔧 Updating notification settings")

        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.notificationSettings)

            Self.logger.info("✅ Notification settings updated")
            Self.logger.debug("📊 Settings: push=\(settings.pushNotificationsEnabled), email=\(settings.emailNotificationsEnabled)")
        } catch {
            Self.logger.error("❌ Failed to encode notification settings: \(error)")
            throw ServiceError.operationFailed("Failed to save notification settings")
        }
    }

    /// Get app settings
    public func getAppSettings() async throws -> AppSettings {
        Self.logger.info("📱 Getting app settings")

        guard let data = userDefaults.data(forKey: Keys.appSettings) else {
            Self.logger.info("📝 No app settings found, returning defaults")
            return AppSettings()
        }

        do {
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            Self.logger.info("✅ Retrieved app settings")
            return settings
        } catch {
            Self.logger.warning("⚠️ Failed to decode app settings, returning defaults: \(error)")
            return AppSettings()
        }
    }

    /// Update app settings
    public func updateAppSettings(_ settings: AppSettings) async throws {
        Self.logger.info("🔧 Updating app settings")

        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.appSettings)

            Self.logger.info("✅ App settings updated")
            Self.logger.debug("📊 Settings: view=\(settings.defaultView.rawValue), sort=\(settings.sortPreference.rawValue)")
        } catch {
            Self.logger.error("❌ Failed to encode app settings: \(error)")
            throw ServiceError.operationFailed("Failed to save app settings")
        }
    }

    /// Update user preferences and return updated user
    public func updateUserPreferences(_ preferences: UserPreferences) async throws -> User {
        Self.logger.info("👤 Updating user preferences for: \(preferences.email)")

        // Update notification settings from preferences
        let notificationSettings = NotificationSettings(
            expirationReminders: true, // Default values - would be customizable in full implementation
            shoppingListUpdates: true,
            householdInvitations: true,
            pushNotificationsEnabled: preferences.pushNotificationsEnabled,
            emailNotificationsEnabled: preferences.emailNotificationsEnabled
        )

        try await updateNotificationSettings(notificationSettings)

        // For MVP, we create a User object with the updated preferences
        // In a full implementation, this would update the user via an API call
        let createdAt: Date = {
            if let createdAtString = authService.currentAuthUser?.createdAt {
                return DateUtilities.dateFromGraphQLOrNow(createdAtString)
            } else {
                return Date()
            }
        }()

        let updatedUser = User(
            id: authService.currentAuthUser?.id ?? UUID().uuidString,
            email: preferences.email,
            name: preferences.name,
            createdAt: createdAt
        )

        Self.logger.info("✅ User preferences updated successfully")
        Self.logger.debug("📊 Updated: name=\(preferences.name), email=\(preferences.email)")

        return updatedUser
    }

    /// Get last selected household ID
    public func getLastSelectedHouseholdId() async -> String? {
        Self.logger.debug("🏠 Getting last selected household ID")

        let householdId = userDefaults.string(forKey: Keys.lastSelectedHousehold)

        if let id = householdId {
            Self.logger.debug("✅ Found last selected household: \(id)")
        } else {
            Self.logger.debug("ℹ️ No last selected household found")
        }

        return householdId
    }

    /// Set last selected household ID
    public func setLastSelectedHouseholdId(_ householdId: String?) async {
        Self.logger.info("🏠 Setting last selected household ID: \(householdId ?? "nil")")

        if let id = householdId {
            userDefaults.set(id, forKey: Keys.lastSelectedHousehold)
            Self.logger.info("✅ Last selected household ID saved: \(id)")
        } else {
            userDefaults.removeObject(forKey: Keys.lastSelectedHousehold)
            Self.logger.info("✅ Last selected household ID cleared")
        }
    }

    /// Get theme preference
    public func getThemePreference() async -> ThemePreference {
        Self.logger.debug("🎨 Getting theme preference")

        let themeString = userDefaults.string(forKey: Keys.themePreference)
        let theme = ThemePreference(rawValue: themeString ?? "") ?? .system

        Self.logger.debug("✅ Theme preference: \(theme.rawValue)")
        return theme
    }

    /// Set theme preference
    public func setThemePreference(_ theme: ThemePreference) async {
        Self.logger.info("🎨 Setting theme preference: \(theme.rawValue)")

        userDefaults.set(theme.rawValue, forKey: Keys.themePreference)
        Self.logger.info("✅ Theme preference saved: \(theme.rawValue)")
    }

    /// Clear all preferences
    public func clearAllPreferences() async throws {
        Self.logger.info("🗑️ Clearing all user preferences")

        let keys = [
            Keys.notificationSettings,
            Keys.appSettings,
            Keys.lastSelectedHousehold,
            Keys.themePreference,
        ]

        for key in keys {
            userDefaults.removeObject(forKey: key)
        }

        Self.logger.info("✅ All user preferences cleared")
    }

    /// Export preferences to dictionary
    public func exportPreferences() async throws -> [String: Any] {
        Self.logger.info("📤 Exporting user preferences")

        var preferences: [String: Any] = [:]

        // Export notification settings
        if let notificationData = userDefaults.data(forKey: Keys.notificationSettings),
           let notificationSettings = try? JSONDecoder().decode(NotificationSettings.self, from: notificationData)
        {
            preferences["notifications"] = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(notificationSettings)
            )
        }

        // Export app settings
        if let appData = userDefaults.data(forKey: Keys.appSettings),
           let appSettings = try? JSONDecoder().decode(AppSettings.self, from: appData)
        {
            preferences["app"] = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(appSettings)
            )
        }

        // Export simple preferences
        if let householdId = userDefaults.string(forKey: Keys.lastSelectedHousehold) {
            preferences["lastHousehold"] = householdId
        }

        if let theme = userDefaults.string(forKey: Keys.themePreference) {
            preferences["theme"] = theme
        }

        preferences["version"] = currentPreferencesVersion

        Self.logger.info("✅ Exported \(preferences.count) preference categories")
        return preferences
    }

    /// Import preferences from dictionary
    public func importPreferences(_ preferences: [String: Any]) async throws {
        Self.logger.info("📥 Importing user preferences")

        // Validate version compatibility
        if let version = preferences["version"] as? Int,
           version > currentPreferencesVersion
        {
            Self.logger.warning("⚠️ Preferences version \(version) is newer than supported \(currentPreferencesVersion)")
            throw ServiceError.validationFailed(["Preferences version not supported"])
        }

        // Import notification settings
        if let notificationDict = preferences["notifications"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: notificationDict)
                let settings = try JSONDecoder().decode(NotificationSettings.self, from: data)
                try await updateNotificationSettings(settings)
                Self.logger.debug("✅ Imported notification settings")
            } catch {
                Self.logger.warning("⚠️ Failed to import notification settings: \(error)")
            }
        }

        // Import app settings
        if let appDict = preferences["app"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: appDict)
                let settings = try JSONDecoder().decode(AppSettings.self, from: data)
                try await updateAppSettings(settings)
                Self.logger.debug("✅ Imported app settings")
            } catch {
                Self.logger.warning("⚠️ Failed to import app settings: \(error)")
            }
        }

        // Import simple preferences
        if let householdId = preferences["lastHousehold"] as? String {
            await setLastSelectedHouseholdId(householdId)
            Self.logger.debug("✅ Imported last selected household")
        }

        if let themeString = preferences["theme"] as? String,
           let theme = ThemePreference(rawValue: themeString)
        {
            await setThemePreference(theme)
            Self.logger.debug("✅ Imported theme preference")
        }

        Self.logger.info("✅ User preferences imported successfully")
    }

    // MARK: - Private Methods

    /// Migrate preferences if version has changed
    private func migratePreferencesIfNeeded() async {
        let storedVersion = userDefaults.integer(forKey: Keys.userPreferencesVersion)

        guard storedVersion < currentPreferencesVersion else {
            Self.logger.debug("ℹ️ Preferences are current (v\(storedVersion))")
            return
        }

        Self.logger.info("🔄 Migrating preferences from v\(storedVersion) to v\(currentPreferencesVersion)")

        // Perform migration logic here if needed
        // For now, we'll just update the version

        userDefaults.set(currentPreferencesVersion, forKey: Keys.userPreferencesVersion)
        Self.logger.info("✅ Preferences migration completed")
    }

    /// Get user-specific key (for multi-user support in the future)
    private func userSpecificKey(for baseKey: String) -> String {
        guard let userId = authService.currentAuthUser?.id else {
            return baseKey
        }
        return "\(baseKey).\(userId)"
    }
}

// MARK: - ServiceLogging Implementation

extension UserPreferencesService: ServiceLogging {
    public func logOperation(_ operation: String, parameters: Any?) {
        Self.logger.info("⚙️ Operation: \(operation)")
        if let parameters = parameters {
            Self.logger.debug("📊 Parameters: \(String(describing: parameters))")
        }
    }

    public func logError(_ error: Error, operation: String) {
        Self.logger.error("❌ Error in \(operation): \(error.localizedDescription)")
    }

    public func logSuccess(_ operation: String, result: Any?) {
        Self.logger.info("✅ Success: \(operation)")
        if let result = result {
            Self.logger.debug("📊 Result: \(String(describing: result))")
        }
    }
}

// MARK: - ServiceHealth Implementation

extension UserPreferencesService: ServiceHealth {
    public func performHealthCheck() async -> ServiceHealthStatus {
        Self.logger.debug("🏥 Performing user preferences service health check")

        let startTime = Date()
        var errors: [String] = []

        // Test UserDefaults access
        do {
            userDefaults.set("health_check", forKey: "pantry.health_test")
            let testValue = userDefaults.string(forKey: "pantry.health_test")
            userDefaults.removeObject(forKey: "pantry.health_test")

            if testValue != "health_check" {
                errors.append("UserDefaults read/write test failed")
            }
        }

        let responseTime = Date().timeIntervalSince(startTime)
        let isHealthy = errors.isEmpty

        let status = ServiceHealthStatus(
            isHealthy: isHealthy,
            lastChecked: Date(),
            errors: errors,
            responseTime: responseTime
        )

        Self.logger.info("🏥 User preferences service health check: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy")")
        return status
    }

    public var isHealthy: Bool {
        get async {
            let status = await performHealthCheck()
            return status.isHealthy
        }
    }
}

// MARK: - Convenience Extensions

public extension UserPreferencesService {
    /// Get user's preferred language code
    func getPreferredLanguage() async -> String {
        do {
            let settings = try await getAppSettings()
            return settings.language
        } catch {
            Self.logger.warning("⚠️ Failed to get preferred language, using default: \(error)")
            return "en"
        }
    }

    /// Check if notifications are enabled
    func areNotificationsEnabled() async -> Bool {
        do {
            let settings = try await getNotificationSettings()
            return settings.pushNotificationsEnabled
        } catch {
            Self.logger.warning("⚠️ Failed to check notification settings, assuming disabled: \(error)")
            return false
        }
    }

    /// Get default view preference
    func getDefaultView() async -> DefaultView {
        do {
            let settings = try await getAppSettings()
            return settings.defaultView
        } catch {
            Self.logger.warning("⚠️ Failed to get default view, using pantry: \(error)")
            return .pantry
        }
    }

    /// Quick save for commonly changed preferences
    func quickSave(
        householdId: String? = nil,
        theme: ThemePreference? = nil
    ) async {
        if let householdId = householdId {
            await setLastSelectedHouseholdId(householdId)
        }

        if let theme = theme {
            await setThemePreference(theme)
        }
    }
}
