/*
 UserService.swift
 PantryKit

 User service implementation with GraphQL integration.
 */

@preconcurrency import Apollo
import ApolloAPI
import Foundation

/// User service implementation with GraphQL integration
@MainActor
public final class UserService: UserServiceProtocol {
    private static let logger = Logger(category: "UserService")

    // MARK: - Properties

    private let authService: any AuthServiceProtocol
    private let graphQLService: GraphQLServiceProtocol
    private let watchManager: WatchManager?

    /// User data cache
    private var userCache: [String: User] = [:]
    
    /// Current user ID for proper cache tracking
    private var currentUserId: String?
    
    /// Cached watched results for query deduplication
    private var currentUserWatch: WatchedResult<User>?
    private var userWatches: [String: WatchedResult<User>] = [:]

    /// Apollo watchers for reactive updates (stored to allow cancellation)
    private var apolloWatchers: [String: GraphQLQueryWatcher<PantryGraphQL.GetUserQuery>] = [:]
    private var currentUserApolloWatcher: GraphQLQueryWatcher<PantryGraphQL.GetCurrentUserQuery>?
    

    // MARK: - Initialization

    public init(authService: any AuthServiceProtocol, graphQLService: GraphQLServiceProtocol, watchManager: WatchManager? = nil) {
        self.authService = authService
        self.graphQLService = graphQLService
        self.watchManager = watchManager
        Self.logger.info("👤 UserService initialized with GraphQL support and WatchManager")
    }

    // MARK: - UserServiceProtocol Implementation

    /// Get the current authenticated user
    public func getCurrentUser() async throws -> User? {
        Self.logger.info("🔍 Getting current user")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            return nil
        }

        return try await fetchCurrentUserFromGraphQL()
    }

    /// Get a user by ID
    public func getUser(id: String) async throws -> User? {
        Self.logger.info("🔍 Getting user by ID: \(id)")

        // Check cache first
        if let cachedUser = userCache[id] {
            Self.logger.debug("📦 Returning cached user: \(cachedUser.name ?? "Unknown")")
            return cachedUser
        }

        let user = try await fetchUserFromGraphQL(userId: id)
        if let user = user {
            userCache[id] = user
        }
        return user
    }

    /// Get multiple users by IDs
    public func getUsersByIds(_ ids: [String]) async throws -> [User] {
        Self.logger.info("🔍 Getting \(ids.count) users by IDs")

        var users: [User] = []

        for id in ids {
            if let user = try await getUser(id: id) {
                users.append(user)
            }
        }

        Self.logger.info("✅ Retrieved \(users.count) users")
        return users
    }

    /// Update user information
    public func updateUser(_ user: User) async throws -> User {
        Self.logger.info("🔧 Updating user: \(user.id)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        let updatedUser = try await updateUserInGraphQL(user: user)

        // Update cache
        userCache[user.id] = updatedUser

        // Apollo's cache normalization is now properly configured in SchemaConfiguration.swift
        // Mutations and queries for the same User (by id) update the same cache entry
        // The watcher will automatically fire when the mutation updates the cache
        if currentUserApolloWatcher != nil || !apolloWatchers.isEmpty {
            Self.logger.info("✨ Watchers will auto-detect mutation through proper cache normalization")
        }

        return updatedUser
    }

    /// Search users by query
    public func searchUsers(query: String) async throws -> [User] {
        Self.logger.info("🔎 Searching users with query: \(query)")

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.warning("⚠️ Empty search query")
            return []
        }

        // TODO: Implement GraphQL query for user search
        throw ServiceError.operationFailed("User search not yet implemented")
    }

    /// Clear current user cache
    public func clearCurrentUserCache() {
        Self.logger.info("🗑️ Clearing current user cache")
        userCache.removeAll()
        currentUserId = nil
        currentUserWatch = nil
        userWatches.removeAll()
        
        // Cancel all Apollo watchers
        apolloWatchers.values.forEach { $0.cancel() }
        apolloWatchers.removeAll()
        currentUserApolloWatcher?.cancel()
        currentUserApolloWatcher = nil
        
        Self.logger.info("✅ User cache and watchers cleared")
    }
    
    // MARK: - Reactive Watch Methods
    
    /// Watch current user with reactive updates
    public func watchCurrentUser() -> WatchedResult<User> {
        Self.logger.info("👁️ Creating watched result for current user")
        
        // Return existing watch if available
        if let existing = currentUserWatch {
            Self.logger.debug("♻️ Reusing existing current user watch")
            return existing
        }
        
        // Create the watched result
        let result = WatchedResult<User>()
        result.setLoading(true)
        
        // Get the Apollo client directly (like in the demo)
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }
        
        // Create the query for current user
        let query = PantryGraphQL.GetCurrentUserQuery()
        
        // Create a REAL Apollo watcher that observes cache changes!
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch
        ) { [weak self, weak result] (graphQLResult: Result<GraphQLResult<PantryGraphQL.GetCurrentUserQuery.Data>, Error>) in
            guard let self = self, let result = result else { return }
            
            switch graphQLResult {
            case let .success(data):
                if let userData = data.data?.currentUser {
                    // Transform GraphQL data to User model
                    let user = User(
                        id: userData.id,
                        authUserId: userData.auth_user_id,
                        email: userData.email,
                        firstName: userData.first_name,
                        lastName: userData.last_name,
                        displayName: userData.display_name,
                        avatarUrl: userData.avatar_url,
                        phone: userData.phone,
                        birthDate: userData.birth_date,
                        managedBy: userData.managed_by,
                        relationshipToManager: userData.relationship_to_manager,
                        primaryHouseholdId: userData.primary_household_id,
                        permissions: userData.permissions,
                        preferences: userData.preferences,
                        isAi: userData.is_ai,
                        createdAt: userData.created_at,
                        updatedAt: userData.updated_at
                    )
                    
                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<User>.DataSource = 
                            data.source == .cache ? .cache : .server
                        result.update(value: user, source: source)
                        result.setLoading(false)
                        
                        // Also update our cache
                        self.currentUserId = user.id
                        self.userCache[user.id] = user
                        
                        Self.logger.info("🔄 Current user watch updated from \(source)")
                    }
                }
                
                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }
                
            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ Current user watch query failed: \(error)")
                }
            }
        }
        
        // Store the watcher so we can cancel it later
        currentUserApolloWatcher = watcher
        
        // Cache the watched result
        currentUserWatch = result
        
        Self.logger.info("✅ Current user watch created with true reactive watching")
        return result
    }
    
    /// Watch specific user by ID with reactive updates
    public func watchUser(id: String) -> WatchedResult<User> {
        Self.logger.info("👁️ Creating watched result for user: \(id)")
        
        // Return existing watch if available
        if let existing = userWatches[id] {
            Self.logger.debug("♻️ Reusing existing watch for user: \(id)")
            return existing
        }
        
        // Create the watched result
        let result = WatchedResult<User>()
        result.setLoading(true)
        
        // Get the Apollo client directly (like in the demo)
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }
        
        // Create the query for the specific user
        let input = PantryGraphQL.GetUserInput(id: id)
        let query = PantryGraphQL.GetUserQuery(input: input)
        
        // Create a REAL Apollo watcher that observes cache changes!
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch
        ) { [weak self, weak result] (graphQLResult: Result<GraphQLResult<PantryGraphQL.GetUserQuery.Data>, Error>) in
            guard let self = self, let result = result else { return }
            
            switch graphQLResult {
            case let .success(data):
                if let userData = data.data?.user {
                    // Transform GraphQL data to User model
                    let user = self.createUserFromGraphQLData(userData)
                    
                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<User>.DataSource = 
                            data.source == .cache ? .cache : .server
                        result.update(value: user, source: source)
                        result.setLoading(false)
                        
                        // Also update our cache
                        self.userCache[user.id] = user
                        
                        Self.logger.info("🔄 User watch updated from \(source) for ID: \(id)")
                    }
                } else {
                    Task { @MainActor in
                        result.setError(ServiceError.notFound("User with id \(id)"))
                        result.setLoading(false)
                    }
                }
                
                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors for user ID: \(id)")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }
                
            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ User watch query failed for ID \(id): \(error)")
                }
            }
        }
        
        // Store the watcher so we can cancel it later
        apolloWatchers[id] = watcher
        
        // Cache the watched result
        userWatches[id] = result
        
        Self.logger.info("✅ User watch created with true reactive watching for ID: \(id)")
        return result
    }
    
    // Helper method to create User from GraphQL data
    private func createUserFromGraphQLData(_ userData: PantryGraphQL.GetUserQuery.Data.User) -> User {
        return User(
            id: userData.id,
            authUserId: userData.auth_user_id,
            email: userData.email,
            firstName: userData.first_name,
            lastName: userData.last_name,
            displayName: userData.display_name,
            avatarUrl: userData.avatar_url,
            phone: userData.phone,
            birthDate: userData.birth_date,
            managedBy: userData.managed_by,
            relationshipToManager: userData.relationship_to_manager,
            primaryHouseholdId: userData.primary_household_id,
            permissions: userData.permissions,
            preferences: userData.preferences,
            isAi: userData.is_ai,
            createdAt: userData.created_at,
            updatedAt: userData.updated_at
        )
    }
}

// MARK: - GraphQL Methods

private extension UserService {
    /// Fetch current user from GraphQL
    func fetchCurrentUserFromGraphQL() async throws -> User? {
        Self.logger.info("🌐 Fetching current user from GraphQL")

        let query = PantryGraphQL.GetCurrentUserQuery()
        let data = try await graphQLService.query(query)

        let userData = data.currentUser

        let user = User(
            id: userData.id,
            authUserId: userData.auth_user_id,
            email: userData.email,
            firstName: userData.first_name,
            lastName: userData.last_name,
            displayName: userData.display_name,
            avatarUrl: userData.avatar_url,
            phone: userData.phone,
            birthDate: userData.birth_date,
            managedBy: userData.managed_by,
            relationshipToManager: userData.relationship_to_manager,
            primaryHouseholdId: userData.primary_household_id,
            permissions: userData.permissions,
            preferences: userData.preferences,
            isAi: userData.is_ai,
            createdAt: userData.created_at,
            updatedAt: userData.updated_at
        )

        Self.logger.info("✅ GraphQL current user fetched: \(user.name ?? "Unknown")")
        return user
    }

    /// Fetch user by ID from GraphQL
    func fetchUserFromGraphQL(userId: String) async throws -> User? {
        Self.logger.info("🌐 Fetching user \(userId) from GraphQL")

        let input = PantryGraphQL.GetUserInput(id: userId)
        let query = PantryGraphQL.GetUserQuery(input: input)

        let data = try await graphQLService.query(query)

        let userData = data.user

        let user = User(
            id: userData.id,
            authUserId: userData.auth_user_id,
            email: userData.email,
            firstName: userData.first_name,
            lastName: userData.last_name,
            displayName: userData.display_name,
            avatarUrl: userData.avatar_url,
            phone: userData.phone,
            birthDate: userData.birth_date,
            managedBy: userData.managed_by,
            relationshipToManager: userData.relationship_to_manager,
            primaryHouseholdId: userData.primary_household_id,
            permissions: userData.permissions,
            preferences: userData.preferences,
            isAi: userData.is_ai,
            createdAt: userData.created_at,
            updatedAt: userData.updated_at
        )

        Self.logger.info("✅ GraphQL user fetched: \(user.name ?? "Unknown")")
        return user
    }

    /// Update user in GraphQL
    func updateUserInGraphQL(user: User) async throws -> User {
        Self.logger.info("🌐 Updating user in GraphQL: \(user.id)")

        // Use the actual first and last name from the User model
        let input = PantryGraphQL.UpdateUserInput(
            id: user.id,
            firstName: .some(user.firstName),
            lastName: .some(user.lastName),
            displayName: user.displayName.map { .some($0) } ?? .none,
            avatarUrl: user.avatarUrl.map { .some($0) } ?? .none,
            phone: user.phone.map { .some($0) } ?? .none,
            birthDate: user.birthDate.map { .some($0) } ?? .none,
            email: user.email.map { .some($0) } ?? .none
        )

        let mutation = PantryGraphQL.UpdateUserMutation(input: input)

        let data = try await graphQLService.mutate(mutation)

        let userData = data.updateUser

        let updatedUser = User(
            id: userData.id,
            authUserId: userData.auth_user_id,
            email: userData.email,
            firstName: userData.first_name,
            lastName: userData.last_name,
            displayName: userData.display_name,
            avatarUrl: userData.avatar_url,
            phone: userData.phone,
            birthDate: userData.birth_date,
            managedBy: userData.managed_by,
            relationshipToManager: userData.relationship_to_manager,
            primaryHouseholdId: userData.primary_household_id,
            permissions: userData.permissions,
            preferences: userData.preferences,
            isAi: userData.is_ai,
            createdAt: userData.created_at,
            updatedAt: userData.updated_at
        )

        Self.logger.info("✅ GraphQL user updated: \(updatedUser.name ?? "Unknown")")

        // Apollo now properly normalizes the cache using the 'id' field
        // Mutations automatically update the same cache entry that queries use
        // The watcher will be notified automatically when the cache updates
        if currentUserApolloWatcher != nil || !apolloWatchers.isEmpty {
            Self.logger.info("✨ Cache normalization fixed - watchers will auto-detect this update")
        }

        return updatedUser
    }
}

// MARK: - ServiceLogging Implementation

extension UserService: ServiceLogging {
    public func logOperation(_ operation: String, parameters: Any?) {
        Self.logger.info("👤 Operation: \(operation)")
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

extension UserService: ServiceHealth {
    public func performHealthCheck() async -> ServiceHealthStatus {
        Self.logger.debug("🏥 Performing user service health check")

        let startTime = Date()
        var errors: [String] = []

        // Check if cache is available
        if userCache.isEmpty {
            Self.logger.debug("User cache is empty (this is normal)")
        }

        // Check authentication service
        if !authService.isAuthenticated {
            errors.append("Authentication service not available")
        }

        // Check Apollo client connectivity
        do {
            // Try a simple query to verify GraphQL connectivity
            _ = try await fetchCurrentUserFromGraphQL()
        } catch {
            errors.append("GraphQL connectivity issue: \(error.localizedDescription)")
        }

        let responseTime = Date().timeIntervalSince(startTime)
        let isHealthy = errors.isEmpty

        let status = ServiceHealthStatus(
            isHealthy: isHealthy,
            lastChecked: Date(),
            errors: errors,
            responseTime: responseTime
        )

        Self.logger.info("🏥 User service health check: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy")")
        return status
    }

    public var isHealthy: Bool {
        get async {
            let status = await performHealthCheck()
            return status.isHealthy
        }
    }
}
