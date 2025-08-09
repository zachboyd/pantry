@preconcurrency import Apollo
import Combine
import Foundation
import SwiftUI

/// Modern dependency injection container for Pantry app
/// Manages service lifecycle and dependency injection following clean architecture principles
@MainActor
@Observable
public final class DependencyContainer {
    private static let logger = Logger.di

    // MARK: - Core Services

    private var _authService: AuthService?
    private var _apolloClientService: ApolloClientService?
    private var _graphQLService: GraphQLService?
    private var _watchManager: WatchManager?
    private var _hydrationService: HydrationService?
    private var _householdService: HouseholdService?
    private var _userService: UserService?
    private var _userPreferencesService: UserPreferencesService?
    private var _pantryItemService: PantryItemServiceProtocol?
    private var _shoppingListService: ShoppingListServiceProtocol?
    private var _notificationService: NotificationServiceProtocol?

    // MARK: - Repositories (Removed)
    // The repository pattern has been removed.
    // Services now interact directly with GraphQL through GraphQLService.

    // MARK: - Utility Services

    private let userPreferencesManager = UserPreferencesManager()
    private var localizationManager: LocalizationManager {
        LocalizationManager.shared
    }

    // MARK: - State

    public var isInitialized = false
    public var isConnected = false
    public var currentUser: User?
    public var initializationError: String?

    // MARK: - Initialization

    public init() {
        Self.logger.debug("🏗️ DependencyContainer initialized")
    }

    // MARK: - Lifecycle Management

    /// Initialize services for authenticated user
    public func initializeForUser(_ userId: String) async throws {
        Self.logger.info("🚀 Initializing services for userId: \(userId)")

        // Check if we need to upgrade from basic to full initialization
        let needsFullInit = _householdService == nil ||
            _userService == nil ||
            _pantryItemService == nil ||
            _shoppingListService == nil ||
            _notificationService == nil

        if !needsFullInit, isInitialized {
            Self.logger.info("✅ Services already fully initialized")
            return
        }

        do {
            Self.logger.info("🔧 Initializing missing services...")

            // Only initialize what's missing
            if needsFullInit {
                try await initializeMissingServices(userId: userId)
            }

            Self.logger.info("✅ All services initialization completed")

            isInitialized = true
            isConnected = true
            initializationError = nil
            Self.logger.info("✅ All services initialized successfully for userId: \(userId)")

        } catch {
            Self.logger.error("❌ Service initialization failed: \(error)")
            initializationError = error.localizedDescription
            isInitialized = false
            isConnected = false
            throw error
        }
    }

    /// Initialize with default state (app startup)
    public func initializeDefault() async {
        Self.logger.info("🚀 Initializing with default state")

        guard !isInitialized else {
            Self.logger.warning("⚠️ Services already initialized")
            return
        }

        // Initialize basic services that don't require authentication
        let authEndpoint = getAuthEndpoint()
        Self.logger.info("🔗 Auth endpoint: \(authEndpoint)")

        let apiClient = AuthClient(authEndpoint: authEndpoint)
        let authTokenManager = AuthTokenManager()

        // Initialize Apollo Client service first (needed for permissions)
        let apolloClientService = ApolloClientService(authService: nil)
        _apolloClientService = apolloClientService

        Self.logger.info("🔑 Creating AuthService with Apollo client...")
        _authService = AuthService(
            apiClient: apiClient,
            authTokenManager: authTokenManager,
            apolloClient: apolloClientService.apolloClient
        )
        Self.logger.info("✅ AuthService created")

        // Update Apollo client service with auth service
        apolloClientService.updateAuthService(_authService)

        // Initialize GraphQL service
        guard let apolloClientService = _apolloClientService else {
            Self.logger.error("❌ ApolloClientService not initialized")
            return
        }
        _graphQLService = GraphQLService(apolloClientService: apolloClientService)

        isInitialized = true
        isConnected = false
        initializationError = nil

        Self.logger.info("✅ Default initialization complete")
    }

    /// Shutdown all services
    public func shutdown() async {
        Self.logger.info("🔄 Shutting down services")

        // Clear all services
        _authService = nil
        _apolloClientService = nil
        _graphQLService = nil
        _watchManager = nil
        _hydrationService = nil
        _householdService = nil
        _userService = nil
        _userPreferencesService = nil
        _pantryItemService = nil
        _shoppingListService = nil
        _notificationService = nil

        isInitialized = false
        isConnected = false
        currentUser = nil
        initializationError = nil

        Self.logger.info("✅ Services shut down successfully")
    }

    // MARK: - Private Helper Methods

    /// Get auth endpoint from configuration
    private func getAuthEndpoint() -> String {
        // Try to get from bundle Info.plist
        if let endpoint = Bundle.main.object(forInfoDictionaryKey: "AUTH_ENDPOINT") as? String,
           !endpoint.isEmpty
        {
            return endpoint
        }

        // Default to localhost for development
        return "http://localhost:3001/api/auth"
    }

    /// Initialize only the missing services (for upgrading from basic to full initialization)
    private func initializeMissingServices(userId _: String) async throws {
        Self.logger.info("🔧 Checking for missing services...")

        // Validate we have the basic services first
        guard let authService = _authService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
        }
        guard _apolloClientService != nil else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "ApolloClientService")
        }
        guard let graphQLService = _graphQLService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "GraphQLService")
        }

        // Repository pattern has been removed - services use GraphQL directly

        // Initialize missing services
        if _householdService == nil {
            Self.logger.info("🏠 Creating HouseholdService...")
            _householdService = try ServiceFactory.createHouseholdService(
                graphQLService: graphQLService,
                authService: authService
            )
        }

        if _userService == nil {
            Self.logger.info("👤 Creating UserService...")
            _userService = try ServiceFactory.createUserService(
                authService: authService,
                graphQLService: graphQLService,
                watchManager: _watchManager
            )
        }

        if _userPreferencesService == nil {
            Self.logger.info("⚙️ Creating UserPreferencesService...")
            _userPreferencesService = try ServiceFactory.createUserPreferencesService(
                authService: authService
            )
        }

        if _pantryItemService == nil {
            Self.logger.info("🥫 Creating PantryItemService...")
            guard let householdService = _householdService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
            }
            _pantryItemService = try ServiceFactory.createPantryItemService(
                householdService: householdService
            )
        }

        if _shoppingListService == nil {
            Self.logger.info("🛒 Creating ShoppingListService...")
            guard let householdService = _householdService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
            }
            _shoppingListService = try ServiceFactory.createShoppingListService(
                householdService: householdService
            )
        }


        if _notificationService == nil {
            Self.logger.info("🔔 Creating NotificationService...")
            _notificationService = try ServiceFactory.createNotificationService()
        }

        Self.logger.info("✅ All missing services created successfully")
    }

    private func initializeServices(userId _: String) async throws {
        do {
            // Validate configuration before proceeding
            try ServiceFactory.validateServiceConfiguration()

            // Repository pattern has been removed - services use GraphQL directly

            // Initialize Apollo Client service first (needed for permissions)
            _apolloClientService = ApolloClientService(authService: nil)

            // Initialize services in dependency order using factory
            _authService = try ServiceFactory.createAuthService(
                authEndpoint: getAuthEndpoint(),
                apolloClient: _apolloClientService?.apolloClient
            )

            // Update Apollo client service with auth service
            _apolloClientService?.updateAuthService(_authService)

            // Enable verbose GraphQL logging in debug builds
            #if DEBUG
                _apolloClientService?.setVerboseLogging(true)
            #endif

            // Initialize GraphQL service after Apollo Client service
            guard let apolloClientService = _apolloClientService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "ApolloClientService")
            }
            _graphQLService = try ServiceFactory.createGraphQLService(
                apolloClientService: apolloClientService
            )
            
            // Initialize WatchManager after Apollo Client service
            _watchManager = WatchManager(apollo: apolloClientService.apollo)
            Self.logger.info("👁️ WatchManager initialized")

            guard let graphQLService = _graphQLService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "GraphQLService")
            }
            
            // Initialize HydrationService with WatchManager
            _hydrationService = try ServiceFactory.createHydrationService(
                graphQLService: graphQLService,
                watchManager: _watchManager
            )
            Self.logger.info("💧 HydrationService initialized")
            guard let authService = _authService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
            }
            _householdService = try ServiceFactory.createHouseholdService(
                graphQLService: graphQLService,
                authService: authService,
                watchManager: _watchManager
            )

            guard let authServiceForUser = _authService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
            }
            _userService = try ServiceFactory.createUserService(
                authService: authServiceForUser,
                graphQLService: graphQLService,
                watchManager: _watchManager
            )

            guard let authServiceForPrefs = _authService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
            }
            _userPreferencesService = try ServiceFactory.createUserPreferencesService(
                authService: authServiceForPrefs
            )

            guard let householdServiceForPantry = _householdService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
            }
            _pantryItemService = try ServiceFactory.createPantryItemService(
                householdService: householdServiceForPantry
            )

            guard let householdServiceForShopping = _householdService else {
                throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
            }
            _shoppingListService = try ServiceFactory.createShoppingListService(
                householdService: householdServiceForShopping
            )

            _notificationService = try ServiceFactory.createNotificationService()

            Self.logger.info("✅ All services initialized using ServiceFactory")
        } catch {
            Self.logger.error("❌ Service initialization failed: \(error)")
            throw DependencyContainerError.serviceInitializationFailed(
                serviceName: "Multiple Services",
                underlying: error
            )
        }
    }

    // MARK: - Service Factory Methods

    public func makeAuthService() throws -> AuthServiceProtocol {
        guard let service = _authService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
        }
        return service
    }

    public func makeHouseholdService() throws -> HouseholdServiceProtocol {
        guard let service = _householdService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
        }
        return service
    }

    public func makePantryItemService() throws -> PantryItemServiceProtocol {
        guard let service = _pantryItemService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "PantryItemService")
        }
        return service
    }

    public func makeShoppingListService() throws -> ShoppingListServiceProtocol {
        guard let service = _shoppingListService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "ShoppingListService")
        }
        return service
    }

    public func makeNotificationService() throws -> NotificationServiceProtocol {
        guard let service = _notificationService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "NotificationService")
        }
        return service
    }

    public func makeApolloClientService() throws -> ApolloClientService {
        guard let service = _apolloClientService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "ApolloClientService")
        }
        return service
    }

    public func makeGraphQLService() throws -> GraphQLService {
        guard let service = _graphQLService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "GraphQLService")
        }
        return service
    }

    public func makeUserService() throws -> UserServiceProtocol {
        guard let service = _userService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "UserService")
        }
        return service
    }

    public func makeUserPreferencesService() throws -> UserPreferencesServiceProtocol {
        guard let service = _userPreferencesService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "UserPreferencesService")
        }
        return service
    }

    // MARK: - Service Access

    public func getAuthService() throws -> AuthServiceProtocol {
        guard let service = _authService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "AuthService")
        }
        return service
    }

    public func getHouseholdService() throws -> HouseholdServiceProtocol {
        guard let service = _householdService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "HouseholdService")
        }
        return service
    }

    public func getPantryItemService() throws -> PantryItemServiceProtocol {
        guard let service = _pantryItemService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "PantryItemService")
        }
        return service
    }

    public func getShoppingListService() throws -> ShoppingListServiceProtocol {
        guard let service = _shoppingListService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "ShoppingListService")
        }
        return service
    }

    public func getNotificationService() throws -> NotificationServiceProtocol {
        guard let service = _notificationService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "NotificationService")
        }
        return service
    }

    public func getApolloClientService() throws -> ApolloClientService {
        guard let service = _apolloClientService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "ApolloClientService")
        }
        return service
    }

    public func getGraphQLService() throws -> GraphQLService {
        guard let service = _graphQLService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "GraphQLService")
        }
        return service
    }
    
    public func getHydrationService() throws -> HydrationService {
        guard let service = _hydrationService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "HydrationService")
        }
        return service
    }

    public func getUserService() throws -> UserServiceProtocol {
        guard let service = _userService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "UserService")
        }
        return service
    }

    public func getUserPreferencesService() throws -> UserPreferencesServiceProtocol {
        guard let service = _userPreferencesService else {
            throw DependencyContainerError.serviceNotInitialized(serviceName: "UserPreferencesService")
        }
        return service
    }

    // MARK: - Utility Services

    public func makeUserPreferencesManager() -> UserPreferencesManager {
        return userPreferencesManager
    }

    public func makeLocalizationManager() -> LocalizationManager {
        return localizationManager
    }

    public func getUserPreferencesManager() -> UserPreferencesManager {
        return userPreferencesManager
    }

    public func getLocalizationManager() -> LocalizationManager {
        return localizationManager
    }

    // MARK: - Service Lifecycle Management

    /// Initialize services that require async setup
    public func initializeServices() async throws {
        Self.logger.info("🚀 Initializing services")
        Self.logger.debug("📊 Current state - isInitialized: \(isInitialized), authService: \(_authService == nil ? "nil" : "exists")")

        // Initialize basic services first if not already done
        if _authService == nil {
            Self.logger.info("🔄 AuthService is nil, calling initializeDefault()")
            await initializeDefault()
        } else {
            Self.logger.debug("✅ AuthService already exists")
        }

        // Test GraphQL connection if available
        if let graphQLService = _graphQLService {
            _ = await graphQLService.testConnection()
        }

        // Perform health checks on all services that support it
        // Note: AuthService doesn't implement ServiceHealth protocol

        if let householdService = _householdService {
            _ = await householdService.isHealthy
        }

        Self.logger.info("✅ Services initialized successfully")
    }

    /// Clear service caches and reset state
    public func clearServices() async {
        Self.logger.info("🧹 Clearing service caches")

        // Clear GraphQL cache
        if let graphQLService = _graphQLService {
            try? await graphQLService.clearCache()
        }

        // Clear any other service-specific caches here
        // Note: Services can implement their own cache clearing logic

        Self.logger.info("✅ Service caches cleared")
    }

    // MARK: - Health Check

    public func performHealthCheck() async -> HealthStatus {
        Self.logger.info("🏥 Performing health check")

        var health = HealthStatus()

        // Service Health
        health.services = isInitialized
        health.connection = isConnected

        Self.logger.info("🏥 Health check complete - Services: \(health.services), Connection: \(health.connection)")

        return health
    }

    public func healthCheck() async -> HealthStatus {
        return await performHealthCheck()
    }

    // MARK: - Debug

    public func printStatus() {
        Self.logger.info("=== DependencyContainer Status ===")
        Self.logger.info("Initialized: \(isInitialized)")
        Self.logger.info("Connected: \(isConnected)")
        Self.logger.info("Current User: \(currentUser?.email ?? "None")")
        Self.logger.info("Error: \(initializationError ?? "None")")
        Self.logger.info("=====================================")
    }

    // MARK: - Backward Compatibility

    /// Get the auth service - available after initialization
    public var authService: AuthServiceProtocol? {
        return try? getAuthService()
    }

    /// Get household service - only available when authenticated
    public var householdService: HouseholdServiceProtocol? {
        return try? getHouseholdService()
    }

    /// Get pantry item service - only available when authenticated
    public var pantryItemService: PantryItemServiceProtocol? {
        return try? getPantryItemService()
    }

    /// Get shopping list service - only available when authenticated
    public var shoppingListService: ShoppingListServiceProtocol? {
        return try? getShoppingListService()
    }

    /// Get notification service - only available when authenticated
    public var notificationService: NotificationServiceProtocol? {
        return try? getNotificationService()
    }

    /// Get Apollo Client service - available after initialization
    public var apolloClientService: ApolloClientService? {
        return try? getApolloClientService()
    }

    /// Get GraphQL service - available after initialization
    public var graphQLService: GraphQLService? {
        return try? getGraphQLService()
    }
    
    /// Get hydration service - available after initialization
    public var hydrationService: HydrationService? {
        return try? getHydrationService()
    }

    /// Get user service - available after initialization
    public var userService: UserServiceProtocol? {
        return try? getUserService()
    }

    /// Get user preferences service - available after initialization
    public var userPreferencesService: UserPreferencesServiceProtocol? {
        return try? getUserPreferencesService()
    }

    /// Get Apollo client directly - available after initialization
    public var apolloClient: ApolloClient? {
        return apolloClientService?.apollo
    }
}

// MARK: - Testing Support

public extension DependencyContainer {
    /// Create a test container with mock dependencies
    static func makeTestContainer() -> DependencyContainer {
        // Create a new instance for testing with mock services
        let container = DependencyContainer()
        // TODO: Inject mock dependencies when provided
        return container
    }
}

// MARK: - Supporting Types

public struct HealthStatus: Sendable {
    public var services: Bool = false
    public var connection: Bool = false

    public var isHealthy: Bool {
        return services && connection
    }
}

// MARK: - Error Types

public enum DependencyContainerError: Error, LocalizedError {
    case serviceNotInitialized(serviceName: String)
    case serviceInitializationFailed(serviceName: String, underlying: Error)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case let .serviceNotInitialized(serviceName):
            return "Service '\(serviceName)' is not initialized"
        case let .serviceInitializationFailed(serviceName, underlying):
            return "Failed to initialize '\(serviceName)': \(underlying.localizedDescription)"
        case let .configurationError(message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - Temporary Protocol Placeholders

// These will be replaced with actual implementations in future phases

// AuthServiceProtocol moved to Services/AuthService.swift

// HouseholdServiceProtocol moved to Services/ServiceProtocols.swift

@MainActor
public protocol PantryItemServiceProtocol: Sendable {
    func getItems(for householdId: String) async throws -> [PantryItem]
    func addItem(_ item: PantryItem) async throws
    func updateItem(_ item: PantryItem) async throws
    func deleteItem(id: String) async throws
}

@MainActor
public protocol ShoppingListServiceProtocol: Sendable {
    func getLists(for householdId: String) async throws -> [ShoppingList]
    func createList(name: String, householdId: String) async throws -> ShoppingList
    func addItem(to listId: String, item: ShoppingListItem) async throws
    func removeItem(from listId: String, itemId: String) async throws
}

@MainActor
public protocol NotificationServiceProtocol: Sendable {
    func scheduleExpirationNotification(for item: PantryItem) async throws
    func cancelNotification(for itemId: String) async throws
}

// Repository protocols have been removed.
// Services now interact directly with GraphQL through GraphQLService.

// MARK: - Temporary Model Placeholders

// Models have been moved to Sources/PantryKit/Models/

public struct PantryItem: Codable, Identifiable, Sendable {
    public let id: String
    public let householdId: String
    public let name: String
    public let quantity: Double
    public let unit: String
    public let category: ItemCategory
    public let expirationDate: Date?
    public let location: String?
    public let notes: String?
    public let addedBy: String
    public let createdAt: Date
    public let updatedAt: Date
}

public enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case produce
    case dairy
    case meat
    case pantry
    case frozen
    case beverages
    case other
}

public struct ShoppingList: Codable, Identifiable, Sendable {
    public let id: String
    public let householdId: String
    public let name: String
    public let items: [ShoppingListItem]
    public let createdBy: String
    public let createdAt: Date
    public let updatedAt: Date
}

public struct ShoppingListItem: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Double
    public let unit: String
    public let category: ItemCategory
    public let isCompleted: Bool
    public let addedBy: String
    public let completedBy: String?
    public let completedAt: Date?
}

