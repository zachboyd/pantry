/*
 ServiceFactory.swift
 PantryKit

 Factory pattern for complex service initialization and configuration
 */

@preconcurrency import Apollo
import Foundation

/// Factory for creating and configuring services with proper dependency injection
@MainActor
public final class ServiceFactory {
    private static let logger = Logger.app

    // MARK: - Service Creation

    /// Create AuthService with all required dependencies
    public static func createAuthService(
        authEndpoint: String = getAuthEndpoint(),
        apolloClient: ApolloClient? = nil
    ) throws -> AuthService {
        logger.info("🏭 Creating AuthService")

        let apiClient = AuthClient(authEndpoint: authEndpoint)
        let authTokenManager = AuthTokenManager()

        let service = AuthService(
            apiClient: apiClient,
            authTokenManager: authTokenManager,
            apolloClient: apolloClient
        )

        logger.info("✅ AuthService created successfully")
        return service
    }

    /// Get auth endpoint from configuration
    public static func getAuthEndpoint() -> String {
        // Try to get from bundle Info.plist
        if let endpoint = Bundle.main.object(forInfoDictionaryKey: "AUTH_ENDPOINT") as? String,
           !endpoint.isEmpty
        {
            return endpoint
        }

        // Default to localhost for development
        return "http://localhost:3001/api/auth"
    }

    /// Create GraphQL Service with all required dependencies
    public static func createGraphQLService(
        apolloClientService: ApolloClientService
    ) throws -> GraphQLService {
        logger.info("🏭 Creating GraphQLService")

        let service = GraphQLService(apolloClientService: apolloClientService)

        logger.info("✅ GraphQLService created successfully")
        return service
    }

    /// Create HouseholdService with all required dependencies
    public static func createHouseholdService(
        graphQLService: GraphQLServiceProtocol,
        authService: any AuthServiceProtocol,
        watchManager: WatchManager? = nil
    ) throws -> HouseholdService {
        logger.info("🏭 Creating HouseholdService")

        let service = HouseholdService(
            graphQLService: graphQLService,
            authService: authService,
            watchManager: watchManager
        )

        logger.info("✅ HouseholdService created successfully")
        return service
    }

    /// Create UserService with all required dependencies
    public static func createUserService(
        authService: any AuthServiceProtocol,
        graphQLService: GraphQLServiceProtocol,
        watchManager: WatchManager? = nil
    ) throws -> UserService {
        logger.info("🏭 Creating UserService with GraphQL")

        let service = UserService(
            authService: authService, 
            graphQLService: graphQLService,
            watchManager: watchManager
        )

        logger.info("✅ UserService created successfully")
        return service
    }

    /// Create UserPreferencesService with all required dependencies
    public static func createUserPreferencesService(
        authService: any AuthServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) throws -> UserPreferencesService {
        logger.info("🏭 Creating UserPreferencesService")

        let service = UserPreferencesService(
            authService: authService,
            userDefaults: userDefaults
        )

        logger.info("✅ UserPreferencesService created successfully")
        return service
    }

    /// Create PantryItemService with all required dependencies
    public static func createPantryItemService(
        householdService: HouseholdServiceProtocol
    ) throws -> PantryItemServiceProtocol {
        logger.info("🏭 Creating PantryItemService")

        let service = PantryItemService(
            householdService: householdService
        )

        logger.info("✅ PantryItemService created successfully")
        return service
    }

    /// Create ShoppingListService with all required dependencies
    public static func createShoppingListService(
        householdService: HouseholdServiceProtocol
    ) throws -> ShoppingListServiceProtocol {
        logger.info("🏭 Creating ShoppingListService")

        let service = ShoppingListService(
            householdService: householdService
        )

        logger.info("✅ ShoppingListService created successfully")
        return service
    }

    /// Create NotificationService - stateless service, no dependencies needed
    public static func createNotificationService() throws -> NotificationServiceProtocol {
        logger.info("🏭 Creating NotificationService")

        let service = NotificationService()

        logger.info("✅ NotificationService created successfully")
        return service
    }
    
    /// Create HydrationService with all required dependencies
    public static func createHydrationService(
        graphQLService: GraphQLServiceProtocol,
        watchManager: WatchManager? = nil
    ) throws -> HydrationService {
        logger.info("🏭 Creating HydrationService")
        
        let service = HydrationService(
            graphQLService: graphQLService,
            watchManager: watchManager
        )
        
        logger.info("✅ HydrationService created successfully")
        return service
    }

    // MARK: - Repository Creation (Removed)
    // The repository pattern has been removed in favor of direct GraphQL service usage.
    // Services now interact directly with GraphQL through Apollo Client.

    // MARK: - Configuration Validation

    /// Validate service configuration before creation
    public static func validateServiceConfiguration() throws {
        logger.info("🔍 Validating service configuration")

        // Add any configuration validation logic here
        // For example, check required environment variables, API endpoints, etc.

        logger.info("✅ Service configuration validation passed")
    }
}

// MARK: - Temporary Service Implementations

// These will be replaced with actual implementations in future phases

// Moved to Services/AuthService.swift - using the actual Better-Auth implementation

// MARK: - Legacy Service Implementations Removed

// Service implementations have been moved to their own files in the Services/ directory
// - PantryItemService.swift
// - ShoppingListService.swift
// - RecipeService.swift
// - NotificationService.swift

// MARK: - Repository Pattern Removed
// The repository pattern has been removed from this architecture.
// All services now interact directly with GraphQL through the GraphQLService,
// which provides a cleaner and more direct data access pattern.
