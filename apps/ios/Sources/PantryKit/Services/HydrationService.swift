@preconcurrency import Apollo
import Foundation

// MARK: - HydrationService

/// Service for hydrating user data after authentication
public final class HydrationService: Sendable {
    private static let logger = Logger(category: "HydrationService")

    private let apolloClient: ApolloClient

    public init(apolloClient: ApolloClient) {
        self.apolloClient = apolloClient
    }

    /// Hydrate user data including households and members
    public func hydrateUserData() async throws -> HydrationResult {
        Self.logger.info("💧 Starting user data hydration")

        // Execute the main hydration query
        let hydrateQuery = PantryGraphQL.HydrateQuery()
        let hydrateResult = try await withCheckedThrowingContinuation { continuation in
            apolloClient.fetch(query: hydrateQuery, cachePolicy: .fetchIgnoringCacheCompletely) { result in
                switch result {
                case let .success(graphQLResult):
                    continuation.resume(returning: graphQLResult)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }

        // Log the raw GraphQL result
        if let errors = hydrateResult.errors {
            Self.logger.error("❌ GraphQL errors in hydration: \(errors)")
        }
        
        guard let hydrateData = hydrateResult.data else {
            Self.logger.error("❌ No data returned from hydration query")
            if let errors = hydrateResult.errors {
                Self.logger.error("❌ Errors: \(errors.map { $0.localizedDescription })")
            }
            throw ServiceError.operationFailed("Failed to fetch hydration data")
        }

        // Extract user data (currentUser is non-optional in the schema)
        let currentUser = hydrateData.currentUser
        
        Self.logger.info("✅ Fetched current user")

        // Convert GraphQL user to our User model
        let user = User(
            id: currentUser.id,
            authUserId: currentUser.auth_user_id,
            email: currentUser.email,
            firstName: currentUser.first_name,
            lastName: currentUser.last_name,
            displayName: currentUser.display_name,
            avatarUrl: currentUser.avatar_url,
            phone: currentUser.phone,
            birthDate: currentUser.birth_date,
            managedBy: currentUser.managed_by,
            relationshipToManager: currentUser.relationship_to_manager,
            createdAt: currentUser.created_at,
            updatedAt: currentUser.updated_at
        )

        
        // Extract households data
        let households: [Household] = hydrateData.households.map { graphQLHousehold in
            Household(
                id: graphQLHousehold.id,
                name: graphQLHousehold.name,
                description: graphQLHousehold.description,
                createdBy: graphQLHousehold.created_by,
                createdAt: DateUtilities.dateFromGraphQL(graphQLHousehold.created_at) ?? Date(),
                updatedAt: DateUtilities.dateFromGraphQL(graphQLHousehold.updated_at) ?? Date(),
                members: [] // Members will be loaded separately
            )
        }
        
        Self.logger.info("✅ Fetched \(households.count) households")
        
        let result = HydrationResult(
            currentUser: user,
            households: households,
            totalMembers: households.count // This is a placeholder - we'll need to fetch actual member counts
        )

        Self.logger.info("✅ Hydration completed successfully")

        return result
    }
}

// MARK: - HydrationResult

/// Result of user data hydration
public struct HydrationResult {
    public let currentUser: User
    public let households: [Household]
    public let totalMembers: Int

    public init(currentUser: User, households: [Household], totalMembers: Int) {
        self.currentUser = currentUser
        self.households = households
        self.totalMembers = totalMembers
    }
}
