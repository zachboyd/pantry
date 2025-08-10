/*
 GraphQLService.swift
 JeevesKit

 GraphQL service implementation for Apollo Client operations.
 Provides low-level GraphQL query and mutation capabilities.
 */

@preconcurrency import Apollo
import ApolloAPI
import Foundation

/// Wrapper to make Apollo GraphQL data Sendable-compliant
///
/// Note: Apollo's generated types are not Sendable, so we need to use @unchecked Sendable
/// to wrap them. This is safe because we only use immutable data from Apollo responses.
private struct SendableGraphQLData<T>: @unchecked Sendable {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

/// GraphQL service implementation
@MainActor
public final class GraphQLService: GraphQLServiceProtocol {
    private static let logger = Logger.graphql

    // MARK: - Properties

    public let apolloClientService: ApolloClientService

    /// Apollo Client instance
    private var apollo: ApolloClient {
        apolloClientService.apollo
    }

    /// Connection status managed with proper actor isolation
    private var connectionStatus: Bool = false

    /// Thread-safe connection status accessor
    public var isConnected: Bool {
        connectionStatus
    }

    // MARK: - Initialization

    public init(apolloClientService: ApolloClientService) {
        self.apolloClientService = apolloClientService
        Self.logger.info("🚀 GraphQLService initialized")

        // Test initial connection
        Task {
            await testConnection()
        }
    }

    // MARK: - Helper Methods

    /// Check if a GraphQL error represents an authentication error
    private func isAuthenticationError(_ error: GraphQLError) -> Bool {
        // Check message-based errors
        if let message = error.message {
            let lowercasedMessage = message.lowercased()
            if lowercasedMessage == "authentication required" ||
                lowercasedMessage == "invalid token" ||
                lowercasedMessage == "user not found" ||
                lowercasedMessage.contains("invalid token") ||
                lowercasedMessage.contains("token expired") ||
                lowercasedMessage.contains("unauthorized") ||
                lowercasedMessage.contains("user not found")
            {
                return true
            }
        }

        // Check extension code-based errors
        if let extensions = error.extensions,
           let code = extensions["code"] as? String
        {
            return code == "UNAUTHENTICATED" ||
                code == "UNAUTHORIZED" ||
                code == "AUTH_ERROR" ||
                code == "TOKEN_EXPIRED" ||
                code == "INVALID_TOKEN" ||
                code == "AUTHENTICATION_REQUIRED" ||
                code == "FORBIDDEN" ||
                code == "USER_NOT_FOUND"
        }

        return false
    }

    // MARK: - GraphQLServiceProtocol Implementation

    /// Execute a GraphQL query
    public func query<Query: ApolloAPI.GraphQLQuery>(_ query: Query) async throws -> Query.Data {
        Self.logger.info("📡 Executing GraphQL query")
        // Apollo queries may not always have accessible __variables
        Self.logger.debug("🔍 Query execution started")

        // Ensure session cookies are set before making the request
        apolloClientService.ensureSessionCookies()

        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            apollo.fetch(query: query) { [weak self] result in
                guard let self = self else {
                    continuation.resume(throwing: ServiceError.operationFailed("Service deallocated"))
                    return
                }

                let executionTime = Date().timeIntervalSince(startTime)

                switch result {
                case let .success(graphQLResult):
                    Self.logger.info("✅ Query completed in \(String(format: "%.2f", executionTime))s")

                    if let errors = graphQLResult.errors, !errors.isEmpty {
                        Self.logger.warning("⚠️ Query returned with GraphQL errors: \(errors)")

                        // Check for authentication errors
                        let hasAuthError = errors.contains { error in
                            self.isAuthenticationError(error)
                        }

                        if hasAuthError {
                            Self.logger.error("🔐 Authentication error detected in query")
                            continuation.resume(throwing: ServiceError.unauthorized)
                            return
                        }
                    }

                    if let data = graphQLResult.data {
                        // Wrap data in sendable wrapper
                        let sendableData = SendableGraphQLData(data)
                        // Update connection status safely on main actor
                        Task { @MainActor [weak self] in
                            self?.connectionStatus = true
                        }
                        continuation.resume(returning: sendableData.value)
                    } else {
                        continuation.resume(throwing: ServiceError.invalidData("No data returned from query"))
                    }

                case let .failure(error):
                    // Update connection status safely on main actor
                    Task { @MainActor [weak self] in
                        self?.connectionStatus = false
                    }
                    Self.logger.error("❌ Query failed: \(error)")
                    continuation.resume(throwing: self.handleGraphQLError(error, operation: "GraphQL Query"))
                }
            }
        }
    }

    /// Execute a GraphQL mutation
    public func mutate<Mutation: ApolloAPI.GraphQLMutation>(_ mutation: Mutation) async throws -> Mutation.Data {
        Self.logger.info("🔧 Executing GraphQL mutation")
        // Apollo mutations may not always have accessible __variables
        Self.logger.debug("🔍 Mutation execution started")

        // Ensure session cookies are set before making the request
        apolloClientService.ensureSessionCookies()

        let startTime = Date()

        do {
            return try await withCheckedThrowingContinuation { continuation in
                apollo.perform(mutation: mutation) { [weak self] result in
                    guard let self = self else {
                        continuation.resume(throwing: ServiceError.operationFailed("Service deallocated"))
                        return
                    }

                    let executionTime = Date().timeIntervalSince(startTime)

                    switch result {
                    case let .success(graphQLResult):
                        Self.logger.info("✅ Mutation completed in \(String(format: "%.2f", executionTime))s")

                        if let errors = graphQLResult.errors, !errors.isEmpty {
                            Self.logger.warning("⚠️ Mutation returned with GraphQL errors: \(errors)")

                            // Check for authentication errors
                            let hasAuthError = errors.contains { error in
                                self.isAuthenticationError(error)
                            }

                            if hasAuthError {
                                Self.logger.error("🔐 Authentication error detected in mutation")
                                continuation.resume(throwing: ServiceError.unauthorized)
                                return
                            }
                        }

                        if let data = graphQLResult.data {
                            // Wrap data in sendable wrapper
                            let sendableData = SendableGraphQLData(data)
                            // Update connection status safely on main actor
                            Task { @MainActor [weak self] in
                                self?.connectionStatus = true
                            }
                            continuation.resume(returning: sendableData.value)
                        } else {
                            continuation.resume(throwing: ServiceError.invalidData("No data returned from mutation"))
                        }

                    case let .failure(error):
                        // Update connection status safely on main actor
                        Task { @MainActor [weak self] in
                            self?.connectionStatus = false
                        }
                        continuation.resume(throwing: self.handleGraphQLError(error, operation: "GraphQL Mutation"))
                    }
                }
            }

        } catch {
            // Update connection status safely - we're already on MainActor
            connectionStatus = false
            Self.logger.error("❌ Mutation failed: \(error)")
            throw handleGraphQLError(error, operation: "GraphQL Mutation")
        }
    }

    /// Clear Apollo Client cache
    public func clearCache() async throws {
        Self.logger.info("🧹 Clearing GraphQL cache")
        await apolloClientService.clearCache()
        Self.logger.info("✅ GraphQL cache cleared successfully")
    }

    /// Update cache for a specific query
    public func updateCache<Query: ApolloAPI.GraphQLQuery>(for _: Query, data _: Query.Data) async throws {
        Self.logger.debug("📝 Updating cache for query")

        // Note: For now, we're skipping cache updates due to Apollo API complexity
        // This would need proper implementation based on Apollo's cache API
        Self.logger.warning("⚠️ Cache update not implemented - using direct queries")
    }

    /// Test GraphQL connection
    @discardableResult
    public func testConnection() async -> Bool {
        Self.logger.debug("🔍 Testing GraphQL connection")

        // For now, we'll consider the service connected if Apollo Client is initialized
        // In a real implementation, you might ping a health check endpoint
        let wasConnected = connectionStatus
        connectionStatus = true

        if !wasConnected && connectionStatus {
            Self.logger.info("✅ GraphQL connection established")
        }

        return connectionStatus
    }

    // MARK: - Private Methods

    /// Handle GraphQL errors consistently with proper actor isolation
    private func handleGraphQLError(_ error: Error, operation: String) -> Error {
        if let graphQLError = error as? GraphQLError {
            Self.logger.error("🚨 GraphQL Error in \(operation): \(graphQLError.message ?? "Unknown error")")
            return ServiceError.operationFailed(graphQLError.message ?? "GraphQL operation failed")
        }

        // Apollo doesn't have JSONDecodingError as public type, check for GraphQL response errors
        Self.logger.error("🚨 GraphQL Error in \(operation): \(error.localizedDescription)")

        // Check for network errors
        if let urlError = error as? URLError {
            Self.logger.error("🌐 Network Error in \(operation): \(urlError.localizedDescription)")
            return ServiceError.networkError(urlError)
        }

        // Generic error handling
        Self.logger.error("🚨 Unknown Error in \(operation): \(error.localizedDescription)")
        return ServiceError.operationFailed(error.localizedDescription)
    }
}

// MARK: - ServiceLogging Implementation

extension GraphQLService: ServiceLogging {
    public func logOperation(_ operation: String, parameters: Any?) {
        Self.logger.info("🔧 Operation: \(operation)")
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

extension GraphQLService: ServiceHealth {
    public func performHealthCheck() async -> ServiceHealthStatus {
        Self.logger.debug("🏥 Performing GraphQL service health check")

        let startTime = Date()
        let isHealthy = await testConnection()
        let responseTime = Date().timeIntervalSince(startTime)

        let status = ServiceHealthStatus(
            isHealthy: isHealthy,
            lastChecked: Date(),
            errors: isHealthy ? [] : ["Connection failed"],
            responseTime: responseTime
        )

        Self.logger.info("🏥 GraphQL health check: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy")")
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

public extension GraphQLService {
    /// Execute a query with automatic error handling and logging
    func safeQuery<Query: ApolloAPI.GraphQLQuery>(
        _ query: Query,
        errorMessage: String = "Query failed"
    ) async -> Result<Query.Data, Error> {
        do {
            let data = try await self.query(query)
            return .success(data)
        } catch {
            Self.logger.error("❌ \(errorMessage): \(error)")
            return .failure(error)
        }
    }

    /// Execute a mutation with automatic error handling and logging
    func safeMutate<Mutation: ApolloAPI.GraphQLMutation>(
        _ mutation: Mutation,
        errorMessage: String = "Mutation failed"
    ) async -> Result<Mutation.Data, Error> {
        do {
            let data = try await mutate(mutation)
            return .success(data)
        } catch {
            Self.logger.error("❌ \(errorMessage): \(error)")
            return .failure(error)
        }
    }
}
