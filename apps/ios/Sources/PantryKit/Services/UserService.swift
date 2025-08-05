/*
 UserService.swift
 PantryKit

 User service implementation with GraphQL integration.
 */

@preconcurrency import Apollo
import Foundation

/// User service implementation with GraphQL integration
@MainActor
public final class UserService: UserServiceProtocol {
    private static let logger = Logger(category: "UserService")

    // MARK: - Properties

    private let authService: any AuthServiceProtocol
    private let apolloClient: ApolloClient

    /// User data cache
    private var userCache: [String: User] = [:]

    // MARK: - Initialization

    public init(authService: any AuthServiceProtocol, apolloClient: ApolloClient) {
        self.authService = authService
        self.apolloClient = apolloClient
        Self.logger.info("👤 UserService initialized with GraphQL support")
    }

    // MARK: - UserServiceProtocol Implementation

    /// Get the current authenticated user
    public func getCurrentUser() async throws -> User? {
        Self.logger.info("🔍 Getting current user")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            return nil
        }

        return try await fetchCurrentUserFromGraphQL(apolloClient: apolloClient)
    }

    /// Get a user by ID
    public func getUser(id: String) async throws -> User? {
        Self.logger.info("🔍 Getting user by ID: \(id)")

        // Check cache first
        if let cachedUser = userCache[id] {
            Self.logger.debug("📦 Returning cached user: \(cachedUser.name ?? "Unknown")")
            return cachedUser
        }

        let user = try await fetchUserFromGraphQL(apolloClient: apolloClient, userId: id)
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

        let updatedUser = try await updateUserInGraphQL(apolloClient: apolloClient, user: user)
        
        // Update cache
        userCache[user.id] = updatedUser
        
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
        Self.logger.info("✅ User cache cleared")
    }

    /// Watch user changes (reactive stream)
    public func watchUser(id: String) -> AsyncStream<User?> {
        Self.logger.info("👀 Creating user watch stream for: \(id)")

        return AsyncStream { continuation in
            Task {
                do {
                    // TODO: Implement GraphQL subscription for user changes
                    // For now, just emit the user once
                    let user = try await getUser(id: id)
                    continuation.yield(user)
                    continuation.finish()
                } catch {
                    Self.logger.error("❌ Failed to watch user: \(error)")
                    continuation.yield(nil)
                    continuation.finish()
                }
            }
        }
    }
}

// MARK: - GraphQL Methods

private extension UserService {
    /// Fetch current user from GraphQL
    func fetchCurrentUserFromGraphQL(apolloClient: ApolloClient) async throws -> User? {
        Self.logger.info("🌐 Fetching current user from GraphQL")

        let query = PantryGraphQL.GetCurrentUserQuery()

        return try await withCheckedThrowingContinuation { continuation in
            apolloClient.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in
                switch result {
                case let .success(graphQLResult):
                    if let userData = graphQLResult.data?.currentUser {
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
                            createdAt: userData.created_at,
                            updatedAt: userData.updated_at
                        )
                        Self.logger.info("✅ GraphQL current user fetched: \(user.name ?? "Unknown")")
                        continuation.resume(returning: user)
                    } else if let errors = graphQLResult.errors {
                        Self.logger.error("❌ GraphQL errors: \(errors)")
                        continuation.resume(throwing: ServiceError.operationFailed("GraphQL errors: \(errors)"))
                    } else {
                        continuation.resume(returning: nil)
                    }
                case let .failure(error):
                    Self.logger.error("❌ GraphQL fetch failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fetch user by ID from GraphQL
    func fetchUserFromGraphQL(apolloClient: ApolloClient, userId: String) async throws -> User? {
        Self.logger.info("🌐 Fetching user \(userId) from GraphQL")

        let input = PantryGraphQL.GetUserInput(id: userId)
        let query = PantryGraphQL.GetUserQuery(input: input)

        return try await withCheckedThrowingContinuation { continuation in
            apolloClient.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in
                switch result {
                case let .success(graphQLResult):
                    if let userData = graphQLResult.data?.user {
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
                            createdAt: userData.created_at,
                            updatedAt: userData.updated_at
                        )
                        Self.logger.info("✅ GraphQL user fetched: \(user.name ?? "Unknown")")
                        continuation.resume(returning: user)
                    } else if let errors = graphQLResult.errors {
                        Self.logger.error("❌ GraphQL errors: \(errors)")
                        continuation.resume(throwing: ServiceError.operationFailed("GraphQL errors: \(errors)"))
                    } else {
                        continuation.resume(returning: nil)
                    }
                case let .failure(error):
                    Self.logger.error("❌ GraphQL fetch failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Update user in GraphQL
    func updateUserInGraphQL(apolloClient: ApolloClient, user: User) async throws -> User {
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
        
        return try await withCheckedThrowingContinuation { continuation in
            apolloClient.perform(mutation: mutation) { result in
                switch result {
                case let .success(graphQLResult):
                    if let userData = graphQLResult.data?.updateUser {
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
                            createdAt: userData.created_at,
                            updatedAt: userData.updated_at
                        )
                        Self.logger.info("✅ GraphQL user updated: \(user.name ?? "Unknown")")
                        continuation.resume(returning: user)
                    } else if let errors = graphQLResult.errors {
                        Self.logger.error("❌ GraphQL errors: \(errors)")
                        continuation.resume(throwing: ServiceError.operationFailed("GraphQL errors: \(errors)"))
                    } else {
                        continuation.resume(throwing: ServiceError.operationFailed("No data returned from update"))
                    }
                case let .failure(error):
                    Self.logger.error("❌ GraphQL update failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
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
            _ = try await fetchCurrentUserFromGraphQL(apolloClient: apolloClient)
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
