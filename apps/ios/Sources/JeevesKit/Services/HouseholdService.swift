/*
 HouseholdService.swift
 JeevesKit

 Household service implementation with GraphQL operations.
 Handles household management and member operations.
 */

@preconcurrency import Apollo
import ApolloAPI
import Foundation

// MARK: - GraphQL Selection Set Protocol

/// Protocol for GraphQL Household selection sets to enable generic mapping
private protocol GraphQLHouseholdSelectionSet {
    var id: String { get }
    var name: String { get }
    var description: String? { get }
    var created_by: String { get }
    var created_at: JeevesGraphQL.DateTime { get }
    var updated_at: JeevesGraphQL.DateTime { get }
    var memberCount: Double? { get }
}

// Conformance for existing GraphQL types
extension JeevesGraphQL.GetHouseholdQuery.Data.Household: GraphQLHouseholdSelectionSet {}
extension JeevesGraphQL.CreateHouseholdMutation.Data.CreateHousehold: GraphQLHouseholdSelectionSet {}
extension JeevesGraphQL.UpdateHouseholdMutation.Data.UpdateHousehold: GraphQLHouseholdSelectionSet {}

/// Household service implementation with GraphQL integration
@MainActor
public final class HouseholdService: HouseholdServiceProtocol {
    private static let logger = Logger(category: "HouseholdService")

    // MARK: - Properties

    private let graphQLService: GraphQLServiceProtocol
    private let authService: any AuthServiceProtocol
    private let watchManager: WatchManager?

    /// Cache for current household to reduce network calls
    private var currentHouseholdCache: Household?
    private var householdsCache: [Household] = []
    private var lastCacheUpdate: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    /// Cached watched results for query deduplication
    private var householdWatches: [String: WatchedResult<Household>] = [:]
    private var householdsListWatch: WatchedResult<[Household]>?
    private var memberWatches: [String: WatchedResult<[HouseholdMember]>] = [:]

    // MARK: - Initialization

    public init(
        graphQLService: GraphQLServiceProtocol,
        authService: any AuthServiceProtocol,
        watchManager: WatchManager? = nil
    ) {
        self.graphQLService = graphQLService
        self.authService = authService
        self.watchManager = watchManager
        Self.logger.info("🏠 HouseholdService initialized")
    }

    // MARK: - HouseholdServiceProtocol Implementation

    /// Get the current user's primary household
    public func getCurrentHousehold() async throws -> Household? {
        Self.logger.info("🔍 Getting current household")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        // Check cache first
        if let cached = currentHouseholdCache,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheTimeout
        {
            Self.logger.debug("📦 Returning cached current household")
            return cached
        }

        do {
            // Use the hydrate query to get authenticated user's household
            // For authenticated household query, we use a placeholder ID since the backend
            // will use the session to determine the user's household
            let query = JeevesGraphQL.GetHouseholdQuery(
                input: JeevesGraphQL.GetHouseholdInput(id: "current"),
            )

            let data = try await graphQLService.query(query)
            let household = mapGraphQLHouseholdToDomain(data.household)

            // Update cache
            currentHouseholdCache = household
            lastCacheUpdate = Date()

            Self.logger.info("✅ Current household retrieved: \(household.name)")
            return household

        } catch {
            Self.logger.error("❌ Failed to get current household: \(error)")
            throw handleServiceError(error, operation: "getCurrentHousehold")
        }
    }

    /// Get all households for the current user
    public func getHouseholds() async throws -> [Household] {
        Self.logger.info("🔍 Getting all households for user")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        // Check cache first
        if !householdsCache.isEmpty,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheTimeout
        {
            Self.logger.debug("📦 Returning cached households list")
            return householdsCache
        }

        do {
            // Use the new ListHouseholds query
            let query = JeevesGraphQL.ListHouseholdsQuery()
            let data = try await graphQLService.query(query)

            // Map GraphQL households to domain models
            householdsCache = data.households.map { graphQLHousehold in
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

            lastCacheUpdate = Date()
            Self.logger.info("✅ Retrieved \(householdsCache.count) household(s)")
            return householdsCache

        } catch {
            Self.logger.error("❌ Failed to get households: \(error)")
            throw handleServiceError(error, operation: "getHouseholds")
        }
    }

    /// Get all households for the current user (alias for getHouseholds)
    public func getUserHouseholds() async throws -> [Household] {
        Self.logger.info("🔍 Getting user households")
        return try await getHouseholds()
    }

    /// Get a specific household by ID
    public func getHousehold(id: String) async throws -> Household {
        Self.logger.info("🔍 Getting household by ID: \(id)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        do {
            // Check if we have it in cache first
            if let cached = currentHouseholdCache, cached.id == id {
                Self.logger.debug("📦 Returning cached household")
                return cached
            }

            // For MVP, use the same query as getCurrentHousehold
            // In a full implementation, you would have a specific getHousehold query
            let query = JeevesGraphQL.GetHouseholdQuery(
                input: JeevesGraphQL.GetHouseholdInput(id: id),
            )

            let data = try await graphQLService.query(query)
            let household = mapGraphQLHouseholdToDomain(data.household)

            Self.logger.info("✅ Household retrieved: \(household.name)")
            return household

        } catch {
            Self.logger.error("❌ Failed to get household: \(error)")
            throw handleServiceError(error, operation: "getHousehold")
        }
    }

    /// Create a new household
    public func createHousehold(name: String, description: String?) async throws -> Household {
        Self.logger.info("🏗️ Creating household: \(name)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        // Use our new trimming extensions
        let trimmedName = name.trimmed()
        guard !trimmedName.isEmpty else {
            Self.logger.warning("⚠️ Invalid household name")
            throw ServiceError.validationFailed(["Household name cannot be empty"])
        }

        do {
            let mutation = JeevesGraphQL.CreateHouseholdMutation(
                input: JeevesGraphQL.CreateHouseholdInput(
                    name: trimmedName,
                    description: description.trimmed().map { GraphQLNullable<String>.some($0) } ?? .none,
                ),
            )

            let data = try await graphQLService.mutate(mutation)
            let household = mapGraphQLHouseholdToDomain(data.createHousehold)

            // Update cache
            currentHouseholdCache = household
            householdsCache = [household]
            lastCacheUpdate = Date()

            Self.logger.info("✅ Household created successfully: \(household.name)")
            return household

        } catch {
            Self.logger.error("❌ Failed to create household: \(error)")
            throw handleServiceError(error, operation: "createHousehold")
        }
    }

    /// Update an existing household
    public func updateHousehold(id: String, name: String, description: String?) async throws -> Household {
        Self.logger.info("🔧 Updating household: \(id)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        // Use our new trimming extensions
        let trimmedName = name.trimmed()
        guard !trimmedName.isEmpty else {
            Self.logger.warning("⚠️ Invalid household name")
            throw ServiceError.validationFailed(["Household name cannot be empty"])
        }

        do {
            let mutation = JeevesGraphQL.UpdateHouseholdMutation(
                input: JeevesGraphQL.UpdateHouseholdInput(
                    id: id,
                    name: GraphQLNullable<String>.some(trimmedName),
                    description: description.trimmed().map { GraphQLNullable<String>.some($0) } ?? .none,
                ),
            )

            let data = try await graphQLService.mutate(mutation)
            let household = mapGraphQLHouseholdToDomain(data.updateHousehold)

            // Update local cache with the new data
            currentHouseholdCache = household
            if let index = householdsCache.firstIndex(where: { $0.id == household.id }) {
                householdsCache[index] = household
            }
            lastCacheUpdate = Date()

            // The mutation response will automatically update Apollo's cache
            // because it returns the same fields (via HouseholdFields fragment)
            // that the watched queries use. This will trigger the watchers automatically.

            // DEBUG: Cache should be automatically updated by the mutation response
            Self.logger.debug("🔍 Mutation completed - cache should now contain updated household data")

            Self.logger.info("✅ Household updated successfully: \(household.name)")
            return household

        } catch {
            Self.logger.error("❌ Failed to update household: \(error)")
            throw handleServiceError(error, operation: "updateHousehold")
        }
    }

    /// Join a household using an invite code
    public func joinHousehold(inviteCode: String) async throws -> Household {
        Self.logger.info("🤝 Joining household with invite code")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.warning("⚠️ Invalid invite code")
            throw ServiceError.validationFailed(["Invite code cannot be empty"])
        }

        // For MVP, we'll mock this functionality
        // In a full implementation, you would have a join household mutation

        // Create a mock household for now
        let household = Household(
            id: UUID().uuidString,
            name: "Joined Household",
            description: "Household joined with invite code",
            createdBy: "other-user-id",
            createdAt: Date(),
            updatedAt: Date(),
            memberCount: 0,
        )

        // Update cache
        currentHouseholdCache = household
        householdsCache = [household]
        lastCacheUpdate = Date()

        Self.logger.info("✅ Successfully joined household: \(household.name)")
        return household
    }

    /// Get household members
    public func getHouseholdMembers(householdId: String) async throws -> [HouseholdMember] {
        Self.logger.info("👥 Getting household members for: \(householdId)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        do {
            let query = JeevesGraphQL.GetHouseholdMembersQuery(
                input: JeevesGraphQL.GetHouseholdMembersInput(householdId: householdId),
            )

            let data = try await graphQLService.query(query)

            // Map GraphQL members to domain models
            let members = data.householdMembers.map { graphQLMember in
                HouseholdMember(
                    id: graphQLMember.id,
                    userId: graphQLMember.user_id,
                    householdId: graphQLMember.household_id,
                    role: MemberRole(rawValue: graphQLMember.role) ?? .member,
                    joinedAt: DateUtilities.dateFromGraphQL(graphQLMember.joined_at) ?? Date(),
                )
            }

            Self.logger.info("✅ Retrieved \(members.count) member(s) for household")
            return members

        } catch {
            Self.logger.error("❌ Failed to get household members: \(error)")
            throw handleServiceError(error, operation: "getHouseholdMembers")
        }
    }

    /// Add a member to a household
    public func addMember(to householdId: String, userId: String, role: MemberRole) async throws -> HouseholdMember {
        Self.logger.info("➕ Adding member to household: \(householdId)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        do {
            let mutation = JeevesGraphQL.AddHouseholdMemberMutation(
                input: JeevesGraphQL.AddHouseholdMemberInput(
                    householdId: householdId,
                    userId: userId,
                    role: role.rawValue,
                ),
            )

            let data = try await graphQLService.mutate(mutation)
            let member = mapGraphQLMemberToDomain(data.addHouseholdMember)

            Self.logger.info("✅ Member added successfully")
            return member

        } catch {
            Self.logger.error("❌ Failed to add member: \(error)")
            throw handleServiceError(error, operation: "addMember")
        }
    }

    /// Update a member's role
    public func updateMemberRole(householdId: String, userId: String, role: MemberRole) async throws -> HouseholdMember {
        Self.logger.info("🔧 Updating member role in household: \(householdId)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        do {
            let mutation = JeevesGraphQL.ChangeHouseholdMemberRoleMutation(
                input: JeevesGraphQL.ChangeHouseholdMemberRoleInput(
                    householdId: householdId,
                    userId: userId,
                    newRole: role.rawValue,
                ),
            )

            let data = try await graphQLService.mutate(mutation)
            let member = mapGraphQLMemberToDomain(data.changeHouseholdMemberRole)

            Self.logger.info("✅ Member role updated successfully")
            return member

        } catch {
            Self.logger.error("❌ Failed to update member role: \(error)")
            throw handleServiceError(error, operation: "updateMemberRole")
        }
    }

    /// Remove a member from a household
    public func removeMember(from householdId: String, userId: String) async throws {
        Self.logger.info("➖ Removing member from household: \(householdId)")

        guard authService.isAuthenticated else {
            Self.logger.warning("⚠️ User not authenticated")
            throw ServiceError.notAuthenticated
        }

        do {
            let mutation = JeevesGraphQL.RemoveHouseholdMemberMutation(
                input: JeevesGraphQL.RemoveHouseholdMemberInput(
                    householdId: householdId,
                    userId: userId,
                ),
            )

            _ = try await graphQLService.mutate(mutation)
            Self.logger.info("✅ Member removed successfully")

        } catch {
            Self.logger.error("❌ Failed to remove member: \(error)")
            throw handleServiceError(error, operation: "removeMember")
        }
    }

    // MARK: - Reactive Watch Methods

    /// Apollo watchers for reactive updates (stored to allow cancellation)
    private var apolloHouseholdWatchers: [String: GraphQLQueryWatcher<JeevesGraphQL.GetHouseholdQuery>] = [:]
    private var apolloHouseholdsListWatcher: GraphQLQueryWatcher<JeevesGraphQL.ListHouseholdsQuery>?
    private var apolloMemberWatchers: [String: GraphQLQueryWatcher<JeevesGraphQL.GetHouseholdMembersQuery>] = [:]

    /// Watch specific household with reactive updates
    public func watchHousehold(id: String) -> WatchedResult<Household> {
        Self.logger.info("👁️ Creating watched result for household: \(id)")

        // Return existing watch if available
        if let existing = householdWatches[id] {
            Self.logger.debug("♻️ Reusing existing watch for household: \(id)")
            return existing
        }

        // Create the watched result
        let result = WatchedResult<Household>()
        result.setLoading(true)

        // Get the Apollo client directly
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }

        // Create the query for the specific household
        let input = JeevesGraphQL.GetHouseholdInput(id: id)
        let query = JeevesGraphQL.GetHouseholdQuery(input: input)

        // Create a REAL Apollo watcher that observes cache changes!
        // Use the EXACT same cache policy as the working watchUser(id) method
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch,
        ) { [weak self, weak result] (graphQLResult: Result<GraphQLResult<JeevesGraphQL.GetHouseholdQuery.Data>, Error>) in
            guard let self, let result else { return }

            // DEBUG: Log every time the watcher is triggered
            Self.logger.debug("👁️ Watcher triggered for household: \(id)")

            switch graphQLResult {
            case let .success(data):
                Self.logger.debug("📊 Watcher success - source: \(data.source), has data: \(data.data?.household != nil)")
                if let householdData = data.data?.household {
                    // Transform GraphQL data to Household model
                    let household = mapGraphQLHouseholdToDomain(householdData)

                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<Household>.DataSource =
                            data.source == .cache ? .cache : .server
                        result.update(value: household, source: source)
                        result.setLoading(false)

                        // Also update our cache - MATCH THE WORKING USER PATTERN
                        if household.id == self.currentHouseholdCache?.id {
                            self.currentHouseholdCache = household
                        }
                        // Also update the households list cache
                        if let index = self.householdsCache.firstIndex(where: { $0.id == household.id }) {
                            self.householdsCache[index] = household
                        }

                        Self.logger.info("🔄 Household watch updated from \(source) for ID: \(id)")
                    }
                } else {
                    Task { @MainActor in
                        result.setError(ServiceError.notFound("Household with id \(id)"))
                        result.setLoading(false)
                    }
                }

                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors for household ID: \(id)")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }

            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ Household watch query failed for ID \(id): \(error)")
                }
            }
        }

        // Store the watcher so we can cancel it later
        apolloHouseholdWatchers[id] = watcher

        // Cache the watched result
        householdWatches[id] = result

        Self.logger.info("✅ Household watch created with true reactive watching for ID: \(id)")
        return result
    }

    /// Watch user's households list with reactive updates
    public func watchUserHouseholds() -> WatchedResult<[Household]> {
        Self.logger.info("👁️ Creating watched result for user households")

        // Return existing watch if available
        if let existing = householdsListWatch {
            Self.logger.debug("♻️ Reusing existing user households watch")
            return existing
        }

        // Create the watched result
        let result = WatchedResult<[Household]>()
        result.setLoading(true)

        // Get the Apollo client directly
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }

        // Create the query for user households
        let query = JeevesGraphQL.ListHouseholdsQuery()

        // Create a REAL Apollo watcher that observes cache changes!
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch,
        ) { [weak self, weak result] (graphQLResult: Result<GraphQLResult<JeevesGraphQL.ListHouseholdsQuery.Data>, Error>) in
            guard let self, let result else { return }

            switch graphQLResult {
            case let .success(data):
                if let householdsData = data.data?.households {
                    // Transform GraphQL data to Household models
                    let households = householdsData.map { graphQLHousehold in
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

                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<[Household]>.DataSource =
                            data.source == .cache ? .cache : .server
                        result.update(value: households, source: source)
                        result.setLoading(false)

                        // Also update our cache
                        self.householdsCache = households
                        self.lastCacheUpdate = Date()

                        Self.logger.info("🔄 User households watch updated from \(source) with \(households.count) households")
                    }
                }

                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors for user households")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }

            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ User households watch query failed: \(error)")
                }
            }
        }

        // Store the watcher so we can cancel it later
        apolloHouseholdsListWatcher = watcher

        // Cache the watched result
        householdsListWatch = result

        Self.logger.info("✅ User households watch created with true reactive watching")
        return result
    }

    /// Watch household members with reactive updates
    public func watchHouseholdMembers(householdId: String) -> WatchedResult<[HouseholdMember]> {
        Self.logger.info("👁️ Creating watched result for household members: \(householdId)")

        // Return existing watch if available
        if let existing = memberWatches[householdId] {
            Self.logger.debug("♻️ Reusing existing members watch for household: \(householdId)")
            return existing
        }

        // Create the watched result
        let result = WatchedResult<[HouseholdMember]>()
        result.setLoading(true)

        // Get the Apollo client directly
        guard let graphQLService = graphQLService as? GraphQLService else {
            Self.logger.error("❌ Cannot access Apollo client - GraphQLService is not the expected type")
            result.setError(ServiceError.serviceUnavailable("GraphQL"))
            return result
        }

        // Create the query for household members
        let input = JeevesGraphQL.GetHouseholdMembersInput(householdId: householdId)
        let query = JeevesGraphQL.GetHouseholdMembersQuery(input: input)

        // Create a REAL Apollo watcher that observes cache changes!
        let watcher = graphQLService.apolloClientService.apollo.watch(
            query: query,
            cachePolicy: .returnCacheDataAndFetch,
        ) { [weak result] (graphQLResult: Result<GraphQLResult<JeevesGraphQL.GetHouseholdMembersQuery.Data>, Error>) in
            guard let result else { return }

            switch graphQLResult {
            case let .success(data):
                if let membersData = data.data?.householdMembers {
                    // Transform GraphQL data to HouseholdMember models
                    let members = membersData.map { graphQLMember in
                        HouseholdMember(
                            id: graphQLMember.id,
                            userId: graphQLMember.user_id,
                            householdId: graphQLMember.household_id,
                            role: MemberRole(rawValue: graphQLMember.role) ?? .member,
                            joinedAt: DateUtilities.dateFromGraphQL(graphQLMember.joined_at) ?? Date(),
                        )
                    }

                    // Update the watched result (this triggers view updates!)
                    Task { @MainActor in
                        let source: WatchedResult<[HouseholdMember]>.DataSource =
                            data.source == .cache ? .cache : .server
                        result.update(value: members, source: source)
                        result.setLoading(false)

                        Self.logger.info("🔄 Household members watch updated from \(source) with \(members.count) members for household: \(householdId)")
                    }
                }

                if let errors = data.errors, !errors.isEmpty {
                    Self.logger.warning("⚠️ Watch query returned errors for household members: \(householdId)")
                    for error in errors {
                        Self.logger.warning("  - \(error.message ?? "Unknown error")")
                    }
                }

            case let .failure(error):
                Task { @MainActor in
                    result.setError(error)
                    result.setLoading(false)
                    Self.logger.error("❌ Household members watch query failed for household \(householdId): \(error)")
                }
            }
        }

        // Store the watcher so we can cancel it later
        apolloMemberWatchers[householdId] = watcher

        // Cache the watched result
        memberWatches[householdId] = result

        Self.logger.info("✅ Household members watch created with true reactive watching for household: \(householdId)")
        return result
    }

    // MARK: - Private Methods

    /// Map GraphQL Household to domain model
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: JeevesGraphQL.GetHouseholdQuery.Data.Household) -> Household {
        Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            memberCount: graphqlHousehold.memberCount.flatMap { Int($0) } ?? 0,
        )
    }

    /// Map GraphQL CreateHousehold to domain model
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: JeevesGraphQL.CreateHouseholdMutation.Data.CreateHousehold) -> Household {
        Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            memberCount: graphqlHousehold.memberCount.flatMap { Int($0) } ?? 0,
        )
    }

    /// Map GraphQL Household to domain model (generic)
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: any GraphQLHouseholdSelectionSet) -> Household {
        Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            memberCount: graphqlHousehold.memberCount.flatMap { Int($0) } ?? 0,
        )
    }

    /// Map GraphQL Member to domain model
    private func mapGraphQLMemberToDomain(_ graphqlMember: JeevesGraphQL.AddHouseholdMemberMutation.Data.AddHouseholdMember) -> HouseholdMember {
        HouseholdMember(
            id: graphqlMember.id,
            userId: graphqlMember.user_id,
            householdId: graphqlMember.household_id,
            role: mapStringRoleToDomain(graphqlMember.role),
            joinedAt: DateUtilities.dateFromGraphQLOrNow(graphqlMember.joined_at.description),
        )
    }

    /// Map GraphQL Member to domain model (for role change)
    private func mapGraphQLMemberToDomain(_ graphqlMember: JeevesGraphQL.ChangeHouseholdMemberRoleMutation.Data.ChangeHouseholdMemberRole) -> HouseholdMember {
        HouseholdMember(
            id: graphqlMember.id,
            userId: graphqlMember.user_id,
            householdId: graphqlMember.household_id,
            role: mapStringRoleToDomain(graphqlMember.role),
            joinedAt: DateUtilities.dateFromGraphQLOrNow(graphqlMember.joined_at.description),
        )
    }

    /// Map string role to domain role
    private func mapStringRoleToDomain(_ roleString: String) -> MemberRole {
        MemberRole(rawValue: roleString) ?? .member
    }

    /// Handle service errors consistently
    private func handleServiceError(_ error: Error, operation: String) -> Error {
        if let serviceError = error as? ServiceError {
            return serviceError
        }

        Self.logger.error("🚨 Unexpected error in \(operation): \(error)")
        return ServiceError.operationFailed("Household operation failed: \(error.localizedDescription)")
    }

    /// Invalidate cached data
    private func invalidateCache() {
        Self.logger.debug("🗑️ Invalidating household cache")
        currentHouseholdCache = nil
        householdsCache = []
        lastCacheUpdate = nil

        // Clear watched results
        householdWatches.removeAll()
        householdsListWatch = nil
        memberWatches.removeAll()

        // Cancel all Apollo watchers
        apolloHouseholdWatchers.values.forEach { $0.cancel() }
        apolloHouseholdWatchers.removeAll()
        apolloHouseholdsListWatcher?.cancel()
        apolloHouseholdsListWatcher = nil
        apolloMemberWatchers.values.forEach { $0.cancel() }
        apolloMemberWatchers.removeAll()

        Self.logger.info("✅ Household cache and watchers cleared")
    }
}

// MARK: - ServiceLogging Implementation

extension HouseholdService: ServiceLogging {
    public func logOperation(_ operation: String, parameters: Any?) {
        Self.logger.info("🏠 Operation: \(operation)")
        if let parameters {
            Self.logger.debug("📊 Parameters: \(String(describing: parameters))")
        }
    }

    public func logError(_ error: Error, operation: String) {
        Self.logger.error("❌ Error in \(operation): \(error.localizedDescription)")
    }

    public func logSuccess(_ operation: String, result: Any?) {
        Self.logger.info("✅ Success: \(operation)")
        if let result {
            Self.logger.debug("📊 Result: \(String(describing: result))")
        }
    }
}

// MARK: - ServiceHealth Implementation

extension HouseholdService: ServiceHealth {
    public func performHealthCheck() async -> ServiceHealthStatus {
        Self.logger.debug("🏥 Performing household service health check")

        let startTime = Date()
        var errors: [String] = []

        // Check authentication
        if !authService.isAuthenticated {
            errors.append("User not authenticated")
        }

        // Check GraphQL service health
        let graphQLHealthy = graphQLService.isConnected
        if !graphQLHealthy {
            errors.append("GraphQL service unavailable")
        }

        let responseTime = Date().timeIntervalSince(startTime)
        let isHealthy = errors.isEmpty

        let status = ServiceHealthStatus(
            isHealthy: isHealthy,
            lastChecked: Date(),
            errors: errors,
            responseTime: responseTime,
        )

        Self.logger.info("🏥 Household service health check: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy")")
        return status
    }

    public var isHealthy: Bool {
        get async {
            let status = await performHealthCheck()
            return status.isHealthy
        }
    }
}
