/*
 ServiceProtocols.swift
 JeevesKit

 Service protocol definitions for the Jeeves app MVP.
 Defines the interface contracts for all business services.
 */

@preconcurrency import Apollo
@preconcurrency import ApolloAPI
import Foundation

// MARK: - Core Service Protocols

// AuthServiceProtocol is defined in AuthService.swift

/// Household Service Protocol
@MainActor
public protocol HouseholdServiceProtocol: Sendable {
    // Core household operations
    func getCurrentHousehold() async throws -> Household?
    func getHouseholds() async throws -> [Household]
    func getUserHouseholds(cachePolicy: CachePolicy) async throws -> [Household]
    func getHousehold(id: LowercaseUUID) async throws -> Household
    func createHousehold(name: String, description: String?) async throws -> Household
    func updateHousehold(id: LowercaseUUID, name: String, description: String?) async throws -> Household
    func joinHousehold(inviteCode: String) async throws -> Household

    // Member management
    func getHouseholdMembers(householdId: LowercaseUUID) async throws -> [HouseholdMember]
    func addMember(to householdId: LowercaseUUID, userId: LowercaseUUID, role: MemberRole) async throws -> HouseholdMember
    func updateMemberRole(householdId: LowercaseUUID, userId: LowercaseUUID, role: MemberRole) async throws -> HouseholdMember
    func removeMember(from householdId: LowercaseUUID, userId: LowercaseUUID) async throws

    // Reactive watch methods
    func watchHousehold(id: LowercaseUUID) -> WatchedResult<Household>
    func watchUserHouseholds() -> WatchedResult<[Household]>
    func watchHouseholdMembers(householdId: LowercaseUUID) -> WatchedResult<[HouseholdMember]>

    // Cache management
    func invalidateCache()
}

// MARK: - HouseholdServiceProtocol Extension for Default Parameters

public extension HouseholdServiceProtocol {
    /// Get all households for the current user with default cache policy
    func getUserHouseholds() async throws -> [Household] {
        try await getUserHouseholds(cachePolicy: .returnCacheDataElseFetch)
    }
}

/// User Service Protocol
@MainActor
public protocol UserServiceProtocol: Sendable {
    func getCurrentUser() async throws -> User?
    func getUser(id: LowercaseUUID) async throws -> User?
    func getUsersByIds(_ ids: [LowercaseUUID]) async throws -> [User]
    func updateUser(_ user: User) async throws -> User
    func searchUsers(query: String) async throws -> [User]

    // Cache management
    func clearCurrentUserCache()

    // Reactive watch methods
    func watchCurrentUser() -> WatchedResult<User>
    func watchUser(id: LowercaseUUID) -> WatchedResult<User>
}

/// User Preferences Service Protocol
@MainActor
public protocol UserPreferencesServiceProtocol: Sendable {
    // Settings management
    func getNotificationSettings() async throws -> NotificationSettings
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    func getAppSettings() async throws -> AppSettings
    func updateAppSettings(_ settings: AppSettings) async throws
    func updateUserPreferences(_ preferences: UserPreferences) async throws -> User

    // Household preferences
    func getLastSelectedHouseholdId() async -> LowercaseUUID?
    func setLastSelectedHouseholdId(_ householdId: LowercaseUUID?) async

    // Theme and display preferences
    func getThemePreference() async -> ThemePreference
    func setThemePreference(_ theme: ThemePreference) async

    // Cache and storage management
    func clearAllPreferences() async throws
    func exportPreferences() async throws -> [String: Any]
    func importPreferences(_ preferences: [String: Any]) async throws
}

/// GraphQL Service Protocol - Low-level GraphQL operations
@MainActor
public protocol GraphQLServiceProtocol: Sendable {
    // Generic query and mutation methods
    func query<Query: ApolloAPI.GraphQLQuery>(_ query: Query) async throws -> Query.Data
    func query<Query: ApolloAPI.GraphQLQuery>(_ query: Query, cachePolicy: CachePolicy) async throws -> Query.Data
    func mutate<Mutation: ApolloAPI.GraphQLMutation>(_ mutation: Mutation) async throws -> Mutation.Data

    // Cache management
    func clearCache() async throws
    func updateCache<Query: ApolloAPI.GraphQLQuery>(for query: Query, data: Query.Data) async throws

    // Connection status
    var isConnected: Bool { get }
    func testConnection() async -> Bool
}

/// Protocol for subscription management
@MainActor
public protocol SubscriptionServiceProtocol: Sendable {
    /// Start user update subscription
    func subscribeToUserUpdates() async throws

    /// Stop user update subscription
    func unsubscribeFromUserUpdates()

    /// Stop all active subscriptions
    func stopAllSubscriptions()
}

// MARK: - Supporting Protocols

/// Logging protocol for consistent service logging
@MainActor
public protocol ServiceLogging {
    func logOperation(_ operation: String, parameters: Any?)
    func logError(_ error: Error, operation: String)
    func logSuccess(_ operation: String, result: Any?)
}

/// Service health monitoring
public protocol ServiceHealth: Sendable {
    func performHealthCheck() async -> ServiceHealthStatus
    var isHealthy: Bool { get async }
}

// MARK: - Supporting Types

/// Notification settings model
public struct NotificationSettings: Codable, Sendable {
    public let expirationReminders: Bool
    public let shoppingListUpdates: Bool
    public let householdInvitations: Bool
    public let pushNotificationsEnabled: Bool
    public let emailNotificationsEnabled: Bool

    public init(
        expirationReminders: Bool = true,
        shoppingListUpdates: Bool = true,
        householdInvitations: Bool = true,
        pushNotificationsEnabled: Bool = true,
        emailNotificationsEnabled: Bool = false
    ) {
        self.expirationReminders = expirationReminders
        self.shoppingListUpdates = shoppingListUpdates
        self.householdInvitations = householdInvitations
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.emailNotificationsEnabled = emailNotificationsEnabled
    }
}

/// App settings model
public struct AppSettings: Codable, Sendable {
    public let defaultView: DefaultView
    public let sortPreference: SortPreference
    public let measurementUnit: MeasurementUnit
    public let language: String
    public let autoSync: Bool

    public init(
        defaultView: DefaultView = .pantry,
        sortPreference: SortPreference = .alphabetical,
        measurementUnit: MeasurementUnit = .metric,
        language: String = "en",
        autoSync: Bool = true
    ) {
        self.defaultView = defaultView
        self.sortPreference = sortPreference
        self.measurementUnit = measurementUnit
        self.language = language
        self.autoSync = autoSync
    }
}

/// Theme preference enumeration
public enum ThemePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Default view enumeration
public enum DefaultView: String, Codable, CaseIterable, Sendable {
    case pantry
    case shoppingList = "shopping_list"
    case recipes
    case household
}

/// Sort preference enumeration
public enum SortPreference: String, Codable, CaseIterable, Sendable {
    case alphabetical
    case dateAdded = "date_added"
    case expirationDate = "expiration_date"
    case category
}

/// Measurement unit enumeration
public enum MeasurementUnit: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial
}

/// User preferences for updating profile and settings
public struct UserPreferences: Sendable {
    public let name: String
    public let email: String
    public let notificationsEnabled: Bool
    public let pushNotificationsEnabled: Bool
    public let emailNotificationsEnabled: Bool

    public init(
        name: String,
        email: String,
        notificationsEnabled: Bool,
        pushNotificationsEnabled: Bool,
        emailNotificationsEnabled: Bool
    ) {
        self.name = name
        self.email = email
        self.notificationsEnabled = notificationsEnabled
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.emailNotificationsEnabled = emailNotificationsEnabled
    }
}

/// Service health status
public struct ServiceHealthStatus: Sendable {
    public let isHealthy: Bool
    public let lastChecked: Date
    public let errors: [String]
    public let responseTime: TimeInterval?

    public init(
        isHealthy: Bool,
        lastChecked: Date = Date(),
        errors: [String] = [],
        responseTime: TimeInterval? = nil
    ) {
        self.isHealthy = isHealthy
        self.lastChecked = lastChecked
        self.errors = errors
        self.responseTime = responseTime
    }
}

// MARK: - Service Errors

/// Common service errors
public enum ServiceError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidData(String)
    case operationFailed(String)
    case serviceUnavailable(String)
    case unauthorized
    case notFound(String)
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "User not authenticated"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .invalidData(message):
            "Invalid data: \(message)"
        case let .operationFailed(message):
            "Operation failed: \(message)"
        case let .serviceUnavailable(service):
            "Service unavailable: \(service)"
        case .unauthorized:
            "Unauthorized access"
        case let .notFound(resource):
            "Resource not found: \(resource)"
        case let .validationFailed(errors):
            "Validation failed: \(errors.joined(separator: ", "))"
        }
    }
}
