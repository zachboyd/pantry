import Combine
import Foundation

/// View model for managing household data and operations
@MainActor
@Observable
public final class HouseholdViewModel {
    private static let logger = Logger.household

    // MARK: - Published Properties

    /// Current household data
    var currentHousehold: Household?

    /// List of available households (for future use)
    var households: [Household] = []

    /// Household creation state
    public var isCreatingHousehold = false
    public var createHouseholdError: String?

    /// Loading state
    public var isLoading = false
    public var lastError: String?

    // MARK: - Dependencies

    private let householdService: HouseholdServiceProtocol
    private let authService: AuthServiceProtocol

    // MARK: - Initialization

    /// Initialize household view model
    /// - Parameters:
    ///   - householdService: Household service for household operations
    ///   - authService: Authentication service for user context
    public init(
        householdService: HouseholdServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.householdService = householdService
        self.authService = authService

        Self.logger.info("🏠 HouseholdViewModel initialized")
    }

    // MARK: - Household Operations

    /// Fetch household data by ID
    /// - Parameter householdId: ID of the household to fetch
    public func fetchHousehold(id householdId: String) async {
        Self.logger.info("📡 Fetching household data for ID: \(householdId)")

        isLoading = true
        lastError = nil

        do {
            let household = try await householdService.getHousehold(id: householdId)
            currentHousehold = household
            isLoading = false
            Self.logger.info("✅ Household data loaded successfully: \(household.name)")
        } catch {
            Self.logger.error("❌ Failed to fetch household: \(error)")
            lastError = error.localizedDescription
            isLoading = false
        }
    }

    /// Create a new household
    /// - Parameters:
    ///   - name: Name of the household
    ///   - description: Optional description of the household
    public func createHousehold(name: String, description: String? = nil) async {
        Self.logger.info("🏗️ Creating new household: \(name)")

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            createHouseholdError = "Household name cannot be empty"
            return
        }

        isCreatingHousehold = true
        createHouseholdError = nil

        do {
            let createdHousehold = try await householdService.createHousehold(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description
            )

            isCreatingHousehold = false
            currentHousehold = createdHousehold
            Self.logger.info("✅ Household created successfully: \(createdHousehold.name)")
        } catch {
            Self.logger.error("❌ Failed to create household: \(error)")
            createHouseholdError = error.localizedDescription
            isCreatingHousehold = false
        }
    }

    /// Add member to current household
    /// - Parameters:
    ///   - userId: ID of the user to add
    ///   - role: Role for the new member ("owner", "admin", "member")
    public func addMember(userId: String, role: String) async {
        guard let household = currentHousehold else {
            Self.logger.error("❌ No current household to add member to")
            return
        }

        Self.logger.info("👥 Adding member \(userId) to household \(household.id) with role \(role)")

        do {
            let memberRole = MemberRole(rawValue: role) ?? .member
            _ = try await householdService.addMember(
                to: household.id,
                userId: userId,
                role: memberRole
            )

            Self.logger.info("✅ Member added successfully")

            // Refetch household data to get updated member list
            await fetchHousehold(id: household.id)
        } catch {
            Self.logger.error("❌ Failed to add member: \(error)")
            lastError = error.localizedDescription
        }
    }

    /// Remove member from current household
    /// - Parameter userId: ID of the user to remove
    public func removeMember(userId: String) async {
        guard let household = currentHousehold else {
            Self.logger.error("❌ No current household to remove member from")
            return
        }

        Self.logger.info("👥 Removing member \(userId) from household \(household.id)")

        do {
            try await householdService.removeMember(
                from: household.id,
                userId: userId
            )

            Self.logger.info("✅ Member removed successfully")

            // Refetch household data to get updated member list
            await fetchHousehold(id: household.id)
        } catch {
            Self.logger.error("❌ Failed to remove member: \(error)")
            lastError = error.localizedDescription
        }
    }

    /// Change member role in current household
    /// - Parameters:
    ///   - userId: ID of the user
    ///   - newRole: New role for the member
    public func changeMemberRole(userId: String, newRole: String) async {
        guard let household = currentHousehold else {
            Self.logger.error("❌ No current household to change member role in")
            return
        }

        Self.logger.info("👥 Changing role of member \(userId) in household \(household.id) to \(newRole)")

        do {
            let memberRole = MemberRole(rawValue: newRole) ?? .member
            _ = try await householdService.updateMemberRole(
                householdId: household.id,
                userId: userId,
                role: memberRole
            )

            Self.logger.info("✅ Member role changed successfully")

            // Refetch household data to get updated member list
            await fetchHousehold(id: household.id)
        } catch {
            Self.logger.error("❌ Failed to change member role: \(error)")
            lastError = error.localizedDescription
        }
    }

    // MARK: - Cache Management

    /// Clear household data cache
    public func clearCache() async {
        Self.logger.info("🧹 Clearing household cache")

        // Clear local cache
        currentHousehold = nil
        households = []
        Self.logger.info("✅ Household cache cleared successfully")
    }
}

// MARK: - Helper Extensions

extension HouseholdViewModel {
    /// Check if user is the owner of the current household
    var isCurrentUserOwner: Bool {
        guard let household = currentHousehold,
              let currentUserId = authService.currentAuthUser?.id
        else {
            return false
        }
        return household.createdBy == currentUserId
    }

    /// Get display name for the current household
    var currentHouseholdDisplayName: String {
        return currentHousehold?.name ?? "No Household"
    }

    /// Check if a household is currently loaded
    var hasCurrentHousehold: Bool {
        return currentHousehold != nil
    }
}

// MARK: - Mock Data (for development)

#if DEBUG
    extension HouseholdViewModel {
        /// Create mock household data for development
        func loadMockData() {
            Self.logger.info("🧪 Loading mock household data")

            // This would typically come from GraphQL, but for development we can create mock data
            // Note: This is just for UI development - replace with actual GraphQL calls
        }
    }
#endif
