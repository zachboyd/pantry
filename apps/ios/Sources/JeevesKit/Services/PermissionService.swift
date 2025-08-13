@preconcurrency import Apollo
import Foundation
import Observation
import SwiftUI

// MARK: - Permission Context

/// Context needed for permission evaluation
/// This contains the current user data and related information from GraphQL cache
public struct PermissionContext: @unchecked Sendable {
    public let currentUserId: String
    public let currentUser: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser?
    public let householdMembers: [HouseholdMemberInfo]

    public struct HouseholdMemberInfo: Sendable {
        public let householdId: String
        public let userId: String
        public let role: String

        public init(householdId: String, userId: String, role: String) {
            self.householdId = householdId
            self.userId = userId
            self.role = role
        }
    }

    public init(
        currentUserId: String,
        currentUser: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser? = nil,
        householdMembers: [HouseholdMemberInfo] = []
    ) {
        self.currentUserId = currentUserId
        self.currentUser = currentUser
        self.householdMembers = householdMembers
    }
}

// MARK: - Permission Service Protocol

@MainActor
public protocol PermissionServiceProtocol: AnyObject, Sendable {
    /// The current permission context
    var permissionContext: PermissionContext? { get }

    /// Subscribe to user updates from Apollo cache
    func subscribeToUserUpdates(apolloClient: ApolloClient) async

    /// Update permission context with new user data
    func updateContext(with user: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser?) async

    /// Clear cached permissions
    func clearPermissions() async

    // MARK: - Permission Check Methods

    /// Check if user can create a household member
    func canCreateHouseholdMember(for householdId: String) -> Bool

    /// Check if user can update a household member
    func canUpdateHouseholdMember(for householdId: String, memberId: String) -> Bool

    /// Check if user can delete a household member
    func canDeleteHouseholdMember(for householdId: String, memberId: String) -> Bool

    /// Check if user can manage a household
    func canManageHousehold(_ householdId: String) -> Bool

    /// Check if user can update household details
    func canUpdateHousehold(_ householdId: String) -> Bool

    /// Check if user can delete a household
    func canDeleteHousehold(_ householdId: String) -> Bool
}

// MARK: - Permission Service Implementation

@MainActor
@Observable
public final class PermissionService: PermissionServiceProtocol {
    // MARK: - Properties

    public private(set) var permissionContext: PermissionContext?
    private var userWatcher: GraphQLQueryWatcher<JeevesGraphQL.GetCurrentUserQuery>?
    private let logger = Logger.permissions
    private let userService: UserServiceProtocol
    private let householdService: HouseholdServiceProtocol

    // Cache for permission data
    private var cachedCurrentUser: User?
    private var cachedHouseholdMembers: [String: [HouseholdMember]] = [:] // householdId -> members

    // MARK: - Initialization

    public init(userService: UserServiceProtocol, householdService: HouseholdServiceProtocol) {
        self.userService = userService
        self.householdService = householdService
        logger.info("PermissionService initialized")
    }

    // MARK: - Public Methods

    /// Subscribe to user updates from Apollo cache
    public func subscribeToUserUpdates(apolloClient: ApolloClient) async {
        // Cancel any existing watcher
        userWatcher?.cancel()

        // Create a new watcher for the current user query
        userWatcher = apolloClient.watch(
            query: JeevesGraphQL.GetCurrentUserQuery(),
            cachePolicy: .returnCacheDataAndFetch
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case let .success(graphQLResult):
                    if let user = graphQLResult.data?.currentUser {
                        self.logger.info("🔄 Received user update for user: \(user.id)")
                        await self.updateContext(with: user)
                    } else {
                        self.logger.warning("⚠️ No current user data in GraphQL result")
                        self.permissionContext = nil
                    }

                case let .failure(error):
                    self.logger.error("Failed to watch user updates: \(error)")
                }
            }
        }
    }

    /// Update permission context with new user data
    public func updateContext(with user: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser?) async {
        guard let user = user else {
            logger.info("Clearing permission context - no user data")
            permissionContext = nil
            return
        }

        // For now, create a simple context with just the user ID
        // In the future, we can fetch household member data here if needed
        let context = PermissionContext(
            currentUserId: user.id,
            currentUser: user,
            householdMembers: []
        )

        permissionContext = context
        logger.info("✅ Permission context updated for user: \(user.id)")
    }

    /// Clear cached permissions
    public func clearPermissions() async {
        permissionContext = nil
        userWatcher?.cancel()
        userWatcher = nil
        logger.info("Permission context cleared")
    }

    // MARK: - Private Helper Methods

    /// Check if a specific member is a manager in the specified household
    private func isMemberManager(householdId: String, memberId: String) -> Bool {
        let members = cachedHouseholdMembers[householdId] ?? []

        if let member = members.first(where: { $0.id == memberId }) {
            return member.role == .manager
        }

        return false
    }

    /// Check if the current user is a manager in the specified household
    private func isCurrentUserManager(in householdId: String) -> Bool {
        // Use cached data if available
        guard let currentUser = cachedCurrentUser else {
            logger.debug("No cached current user for manager check")
            // Try to load it asynchronously for next time
            Task {
                await refreshUserCache()
            }
            return false
        }

        // Check cached household members
        let members = cachedHouseholdMembers[householdId] ?? []

        if members.isEmpty {
            // Try to load members asynchronously for next time
            Task {
                await refreshHouseholdMembersCache(householdId: householdId)
            }
            logger.debug("No cached members data for household: \(householdId)")
            return false
        }

        // Find the current user's membership in this household
        let currentUserMembership = members.first { member in
            member.userId == currentUser.id
        }

        // Check if user has manager role
        if let membership = currentUserMembership {
            let isManager = membership.role == .manager
            logger.debug("User \(currentUser.id) is \(isManager ? "a manager" : "not a manager") in household \(householdId)")
            return isManager
        }

        logger.debug("User \(currentUser.id) is not a member of household \(householdId)")
        return false
    }

    // MARK: - Permission Check Methods

    /// Check if user can create a household member
    public func canCreateHouseholdMember(for householdId: String) -> Bool {
        logger.debug("Checking canCreateHouseholdMember for household: \(householdId)")

        // Only managers can create household members
        let canCreate = isCurrentUserManager(in: householdId)
        logger.info("canCreateHouseholdMember(\(householdId)): \(canCreate)")
        return canCreate
    }

    /// Check if user can update a household member
    public func canUpdateHouseholdMember(for householdId: String, memberId: String) -> Bool {
        logger.debug("Checking canUpdateHouseholdMember for household: \(householdId), member: \(memberId)")

        // Check if current user is a manager
        guard isCurrentUserManager(in: householdId) else {
            logger.info("canUpdateHouseholdMember(\(householdId), \(memberId)): false - current user is not a manager")
            return false
        }

        // Managers cannot update other managers
        if isMemberManager(householdId: householdId, memberId: memberId) {
            logger.info("canUpdateHouseholdMember(\(householdId), \(memberId)): false - cannot update another manager")
            return false
        }

        logger.info("canUpdateHouseholdMember(\(householdId), \(memberId)): true - current user is manager and target is not a manager")
        return true
    }

    /// Check if user can delete a household member
    /// Uses the same logic as canUpdateHouseholdMember - managers can delete non-managers
    public func canDeleteHouseholdMember(for householdId: String, memberId: String) -> Bool {
        logger.debug("Checking canDeleteHouseholdMember for household: \(householdId), member: \(memberId)")

        // Use the same logic as updating - managers can delete non-managers
        let canDelete = canUpdateHouseholdMember(for: householdId, memberId: memberId)
        logger.info("canDeleteHouseholdMember(\(householdId), \(memberId)): \(canDelete)")
        return canDelete
    }

    /// Check if user can manage a household
    public func canManageHousehold(_ householdId: String) -> Bool {
        logger.debug("Checking canManageHousehold for household: \(householdId)")

        // Only managers can manage households
        let canManage = isCurrentUserManager(in: householdId)
        logger.info("canManageHousehold(\(householdId)): \(canManage)")
        return canManage
    }

    /// Check if user can update household details
    public func canUpdateHousehold(_ householdId: String) -> Bool {
        logger.debug("Checking canUpdateHousehold for household: \(householdId)")

        // Only managers can update household details
        let canUpdate = isCurrentUserManager(in: householdId)
        logger.info("canUpdateHousehold(\(householdId)): \(canUpdate)")
        return canUpdate
    }

    /// Check if user can delete a household
    public func canDeleteHousehold(_ householdId: String) -> Bool {
        logger.debug("Checking canDeleteHousehold for household: \(householdId)")

        // Only managers can delete households
        let canDelete = isCurrentUserManager(in: householdId)
        logger.info("canDeleteHousehold(\(householdId)): \(canDelete)")
        return canDelete
    }

    // MARK: - Utility Properties

    /// Check if permissions are loaded
    public var isLoaded: Bool {
        permissionContext != nil
    }

    // MARK: - Cache Management

    /// Refresh the cached user data
    public func refreshUserCache() async {
        do {
            cachedCurrentUser = try await userService.getCurrentUser()
            logger.info("User cache refreshed")
        } catch {
            logger.error("Failed to refresh user cache: \(error)")
        }
    }

    /// Refresh the cached household members for a specific household
    public func refreshHouseholdMembersCache(householdId: String) async {
        do {
            let members = try await householdService.getHouseholdMembers(householdId: householdId)
            cachedHouseholdMembers[householdId] = members
            logger.info("Household members cache refreshed for household: \(householdId)")
        } catch {
            logger.error("Failed to refresh household members cache: \(error)")
        }
    }
}

// MARK: - Environment Key

private struct PermissionServiceKey: EnvironmentKey {
    static let defaultValue: PermissionService? = nil
}

public extension EnvironmentValues {
    /// Access the permission service from the environment
    var permissionService: PermissionService? {
        get { self[PermissionServiceKey.self] }
        set { self[PermissionServiceKey.self] = newValue }
    }
}

// MARK: - View Modifier

public extension View {
    /// Inject the permission service into the environment
    func withPermissionService(_ service: PermissionService) -> some View {
        environment(\.permissionService, service)
    }
}
