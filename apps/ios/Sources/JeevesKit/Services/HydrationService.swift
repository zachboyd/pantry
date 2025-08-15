@preconcurrency import Apollo
import ApolloAPI
import Foundation

// MARK: - HydrationService

/// Service for hydrating user data after authentication
@MainActor
public final class HydrationService {
    private static let logger = Logger(category: "HydrationService")

    private let graphQLService: GraphQLServiceProtocol
    private let watchManager: WatchManager?

    /// Cached watched result for hydration
    private var hydrationWatch: WatchedResult<HydrationResult>?

    /// Apollo watcher for reactive updates
    private var apolloHydrationWatcher: GraphQLQueryWatcher<JeevesGraphQL.HydrateQuery>?

    public init(graphQLService: GraphQLServiceProtocol, watchManager: WatchManager? = nil) {
        self.graphQLService = graphQLService
        self.watchManager = watchManager
    }

    /// Hydrate user data including households and members
    public func hydrateUserData() async throws -> HydrationResult {
        Self.logger.info("💧 Starting user data hydration")

        // Execute the main hydration query using GraphQLService
        // This will automatically handle authentication errors and throw ServiceError.unauthorized
        let hydrateQuery = JeevesGraphQL.HydrateQuery()
        let hydrateData = try await graphQLService.query(hydrateQuery)

        // Extract user data (currentUser is non-optional in the schema)
        let currentUser = hydrateData.currentUser

        Self.logger.info("✅ Fetched current user")
        Self.logger.info("👤 Business User ID: \(currentUser.id)")
        Self.logger.info("🔑 Auth User ID: \(currentUser.auth_user_id ?? "nil")")

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
            primaryHouseholdId: currentUser.primary_household_id,
            isAi: currentUser.is_ai,
            createdAt: currentUser.created_at,
            updatedAt: currentUser.updated_at,
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
                memberCount: graphQLHousehold.memberCount.flatMap { Int($0) } ?? 0,
            )
        }

        Self.logger.info("✅ Fetched \(households.count) households")

        let result = HydrationResult(
            currentUser: user,
            households: households,
        )

        Self.logger.info("✅ Hydration completed successfully")

        return result
    }

    /// Watch hydration data with reactive updates
    public func watchHydration() -> WatchedResult<HydrationResult> {
        Self.logger.info("👁️ Creating watched result for hydration data")

        // Return existing watch if available
        if let existing = hydrationWatch {
            Self.logger.debug("♻️ Reusing existing hydration watch")
            return existing
        }

        // Create the watched result
        let result = WatchedResult<HydrationResult>()
        result.setLoading(true)

        // Get the Apollo client directly
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }

        // Create the hydration query
        let query = JeevesGraphQL.HydrateQuery()

        // Create a REAL Apollo watcher that observes cache changes!
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch,
        ) { [weak result] (graphQLResult: Result<GraphQLResult<JeevesGraphQL.HydrateQuery.Data>, Error>) in
            guard let result else { return }

            switch graphQLResult {
            case let .success(data):
                if let hydrateData = data.data {
                    // Extract user data
                    let currentUser = hydrateData.currentUser

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
                        primaryHouseholdId: currentUser.primary_household_id,
                        isAi: currentUser.is_ai,
                        createdAt: currentUser.created_at,
                        updatedAt: currentUser.updated_at,
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
                            memberCount: graphQLHousehold.memberCount.flatMap { Int($0) } ?? 0,
                        )
                    }

                    let hydrationResult = HydrationResult(
                        currentUser: user,
                        households: households,
                    )

                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<HydrationResult>.DataSource =
                            data.source == .cache ? .cache : .server
                        result.update(value: hydrationResult, source: source)
                        result.setLoading(false)

                        Self.logger.info("🔄 Hydration watch updated from \(source) with \(households.count) households")
                    }
                }

                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors for hydration")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }

            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ Hydration watch query failed: \(error)")
                }
            }
        }

        // Store the watcher so we can cancel it later
        apolloHydrationWatcher = watcher

        // Cache the watched result
        hydrationWatch = result

        Self.logger.info("✅ Hydration watch created with true reactive watching")
        return result
    }

    /// Clear cached hydration data and cancel watchers
    public func clearCache() {
        Self.logger.info("🗑️ Clearing hydration cache and watchers")

        hydrationWatch = nil

        // Cancel Apollo watcher
        apolloHydrationWatcher?.cancel()
        apolloHydrationWatcher = nil

        Self.logger.info("✅ Hydration cache and watchers cleared")
    }
}

// MARK: - HydrationResult

/// Result of user data hydration
public struct HydrationResult: Sendable {
    public let currentUser: User
    public let households: [Household]

    public init(currentUser: User, households: [Household]) {
        self.currentUser = currentUser
        self.households = households
    }
}
