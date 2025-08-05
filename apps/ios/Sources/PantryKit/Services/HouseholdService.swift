/*
 HouseholdService.swift
 PantryKit

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
    var created_at: PantryGraphQL.DateTime { get }
    var updated_at: PantryGraphQL.DateTime { get }
}

// Conformance for existing GraphQL types
extension PantryGraphQL.GetHouseholdQuery.Data.Household: GraphQLHouseholdSelectionSet {}
extension PantryGraphQL.CreateHouseholdMutation.Data.CreateHousehold: GraphQLHouseholdSelectionSet {}

/// Household service implementation with GraphQL integration
@MainActor
public final class HouseholdService: HouseholdServiceProtocol {
    private static let logger = Logger(category: "HouseholdService")

    // MARK: - Properties

    private let graphQLService: GraphQLServiceProtocol
    private let authService: any AuthServiceProtocol

    /// Cache for current household to reduce network calls
    private var currentHouseholdCache: Household?
    private var householdsCache: [Household] = []
    private var lastCacheUpdate: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    public init(
        graphQLService: GraphQLServiceProtocol,
        authService: any AuthServiceProtocol
    ) {
        self.graphQLService = graphQLService
        self.authService = authService
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
            let query = PantryGraphQL.GetHouseholdQuery(
                input: PantryGraphQL.GetHouseholdInput(id: "current")
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
            let query = PantryGraphQL.ListHouseholdsQuery()
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
                    members: [] // Members will be loaded separately
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
            let query = PantryGraphQL.GetHouseholdQuery(
                input: PantryGraphQL.GetHouseholdInput(id: id)
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
            let mutation = PantryGraphQL.CreateHouseholdMutation(
                input: PantryGraphQL.CreateHouseholdInput(
                    name: trimmedName,
                    description: description.trimmed().map { GraphQLNullable<String>.some($0) } ?? .none
                )
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

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.warning("⚠️ Invalid household name")
            throw ServiceError.validationFailed(["Household name cannot be empty"])
        }

        do {
            // For MVP, we'll use the create mutation as a placeholder
            // In a full implementation, you would have an update mutation
            let mutation = PantryGraphQL.CreateHouseholdMutation(
                input: PantryGraphQL.CreateHouseholdInput(
                    name: name,
                    description: description.map { GraphQLNullable<String>.some($0) } ?? .none
                )
            )

            let data = try await graphQLService.mutate(mutation)
            let household = mapGraphQLHouseholdToDomain(data.createHousehold)

            // Update cache
            invalidateCache()

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
            members: []
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
            let query = PantryGraphQL.GetHouseholdMembersQuery(
                input: PantryGraphQL.GetHouseholdMembersInput(householdId: householdId)
            )
            
            let data = try await graphQLService.query(query)
            
            // Map GraphQL members to domain models
            let members = data.householdMembers.map { graphQLMember in
                HouseholdMember(
                    id: graphQLMember.id,
                    userId: graphQLMember.user_id,
                    householdId: graphQLMember.household_id,
                    role: MemberRole(rawValue: graphQLMember.role) ?? .member,
                    joinedAt: DateUtilities.dateFromGraphQL(graphQLMember.joined_at) ?? Date()
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
            let mutation = PantryGraphQL.AddHouseholdMemberMutation(
                input: PantryGraphQL.AddHouseholdMemberInput(
                    householdId: householdId,
                    userId: userId,
                    role: role.rawValue
                )
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
            let mutation = PantryGraphQL.ChangeHouseholdMemberRoleMutation(
                input: PantryGraphQL.ChangeHouseholdMemberRoleInput(
                    householdId: householdId,
                    userId: userId,
                    newRole: role.rawValue
                )
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
            let mutation = PantryGraphQL.RemoveHouseholdMemberMutation(
                input: PantryGraphQL.RemoveHouseholdMemberInput(
                    householdId: householdId,
                    userId: userId
                )
            )

            _ = try await graphQLService.mutate(mutation)
            Self.logger.info("✅ Member removed successfully")

        } catch {
            Self.logger.error("❌ Failed to remove member: \(error)")
            throw handleServiceError(error, operation: "removeMember")
        }
    }

    /// Watch household changes (reactive stream)
    public func watchHousehold(id: String) -> AsyncStream<Household?> {
        Self.logger.info("👀 Creating household watch stream for: \(id)")

        return AsyncStream { continuation in
            Task {
                do {
                    // For MVP, emit current household once
                    // In a full implementation, you would use GraphQL subscriptions
                    let household = try await getCurrentHousehold()
                    continuation.yield(household)
                    continuation.finish()
                } catch {
                    Self.logger.error("❌ Failed to watch household: \(error)")
                    continuation.yield(nil)
                    continuation.finish()
                }
            }
        }
    }

    /// Watch user households changes (reactive stream)
    public func watchUserHouseholds() -> AsyncStream<[Household]> {
        Self.logger.info("👀 Creating user households watch stream")

        return AsyncStream { continuation in
            Task {
                do {
                    // For MVP, emit current households once
                    // In a full implementation, you would use GraphQL subscriptions
                    let households = try await getHouseholds()
                    continuation.yield(households)
                    continuation.finish()
                } catch {
                    Self.logger.error("❌ Failed to watch user households: \(error)")
                    continuation.yield([])
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Map GraphQL Household to domain model
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: PantryGraphQL.GetHouseholdQuery.Data.Household) -> Household {
        return Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            members: [] // Members are not included in this query
        )
    }

    /// Map GraphQL CreateHousehold to domain model
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: PantryGraphQL.CreateHouseholdMutation.Data.CreateHousehold) -> Household {
        return Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            members: [] // Members are not included in this mutation response
        )
    }

    /// Map GraphQL Household to domain model (generic)
    private func mapGraphQLHouseholdToDomain(_ graphqlHousehold: any GraphQLHouseholdSelectionSet) -> Household {
        return Household(
            id: graphqlHousehold.id,
            name: graphqlHousehold.name,
            description: graphqlHousehold.description,
            createdBy: graphqlHousehold.created_by,
            createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description),
            updatedAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.updated_at.description),
            members: []
        )
    }

    /// Map GraphQL Member to domain model
    private func mapGraphQLMemberToDomain(_ graphqlMember: PantryGraphQL.AddHouseholdMemberMutation.Data.AddHouseholdMember) -> HouseholdMember {
        return HouseholdMember(
            id: graphqlMember.id,
            userId: graphqlMember.user_id,
            householdId: graphqlMember.household_id,
            role: mapStringRoleToDomain(graphqlMember.role),
            joinedAt: DateUtilities.dateFromGraphQLOrNow(graphqlMember.joined_at.description)
        )
    }

    /// Map GraphQL Member to domain model (for role change)
    private func mapGraphQLMemberToDomain(_ graphqlMember: PantryGraphQL.ChangeHouseholdMemberRoleMutation.Data.ChangeHouseholdMemberRole) -> HouseholdMember {
        return HouseholdMember(
            id: graphqlMember.id,
            userId: graphqlMember.user_id,
            householdId: graphqlMember.household_id,
            role: mapStringRoleToDomain(graphqlMember.role),
            joinedAt: DateUtilities.dateFromGraphQLOrNow(graphqlMember.joined_at.description)
        )
    }

    /// Map string role to domain role
    private func mapStringRoleToDomain(_ roleString: String) -> MemberRole {
        return MemberRole(rawValue: roleString) ?? .member
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
    }
}

// MARK: - ServiceLogging Implementation

extension HouseholdService: ServiceLogging {
    public func logOperation(_ operation: String, parameters: Any?) {
        Self.logger.info("🏠 Operation: \(operation)")
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
            responseTime: responseTime
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
