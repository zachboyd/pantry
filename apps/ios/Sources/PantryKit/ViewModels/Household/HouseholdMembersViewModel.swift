import Foundation
import Observation

// MARK: - HouseholdMembersViewModel

/// ViewModel for managing household members
@Observable @MainActor
public final class HouseholdMembersViewModel: BaseReactiveViewModel<HouseholdMembersViewModel.State, HouseholdMembersDependencies> {
    private static let logger = Logger.household

    // MARK: - State

    public struct State: Sendable {
        var household: Household?
        var members: [HouseholdMemberInfo] = []
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var showingInviteSheet = false
        var inviteCode = ""
        var searchText = ""
        var filteredMembers: [HouseholdMemberInfo] = []

        // Member management
        var selectedMemberId: String?
        var showingMemberActions = false
        var showingRemoveMemberConfirmation = false
        var memberToRemove: HouseholdMemberInfo?
    }

    /// Extended member information combining HouseholdMember with User details
    public struct HouseholdMemberInfo: Identifiable, Sendable {
        public let id: String
        public let userId: String
        public let householdId: String
        public let role: MemberRole
        public let joinedAt: Date
        public let user: User?

        public var displayName: String {
            user?.name ?? user?.email ?? "Unknown User"
        }

        public var canBeRemoved: Bool {
            role != .owner
        }

        public var canChangeRole: Bool {
            role != .owner
        }

        public init(member: HouseholdMember, user: User? = nil) {
            id = member.id
            userId = member.userId
            householdId = member.householdId
            role = member.role
            joinedAt = member.joinedAt
            self.user = user
        }
    }

    // MARK: - Dependencies

    public let householdId: String

    // MARK: - Computed Properties

    public var household: Household? {
        state.household
    }

    public var members: [HouseholdMemberInfo] {
        state.members
    }

    public var searchText: String {
        get { state.searchText }
        set {
            updateState { $0.searchText = newValue }
            filterMembers()
        }
    }

    public var displayedMembers: [HouseholdMemberInfo] {
        state.searchText.isEmpty ? state.members : state.filteredMembers
    }

    public var ownerMember: HouseholdMemberInfo? {
        state.members.first { $0.role == .owner }
    }

    public var adminMembers: [HouseholdMemberInfo] {
        state.members.filter { $0.role == .admin }
    }

    public var regularMembers: [HouseholdMemberInfo] {
        state.members.filter { $0.role == .member }
    }

    public var currentUserMember: HouseholdMemberInfo? {
        guard let currentUserId = dependencies.authService.currentUser?.id else { return nil }
        return state.members.first { $0.userId == currentUserId }
    }

    public var isCurrentUserOwner: Bool {
        currentUserMember?.role == .owner
    }

    public var isCurrentUserAdmin: Bool {
        let role = currentUserMember?.role
        return role == .owner || role == .admin
    }

    public var canManageMembers: Bool {
        isCurrentUserAdmin
    }

    public var isLoading: Bool {
        loadingStates.isAnyLoading
    }

    public var showingError: Bool {
        state.showingError
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    public var showingInviteSheet: Bool {
        get { state.showingInviteSheet }
        set { updateState { $0.showingInviteSheet = newValue } }
    }

    public var inviteCode: String {
        state.inviteCode
    }

    public var showingMemberActions: Bool {
        get { state.showingMemberActions }
        set { updateState { $0.showingMemberActions = newValue } }
    }

    public var selectedMember: HouseholdMemberInfo? {
        guard let selectedId = state.selectedMemberId else { return nil }
        return state.members.first { $0.id == selectedId }
    }

    public var showingRemoveMemberConfirmation: Bool {
        get { state.showingRemoveMemberConfirmation }
        set { updateState { $0.showingRemoveMemberConfirmation = newValue } }
    }

    public var memberToRemove: HouseholdMemberInfo? {
        state.memberToRemove
    }

    // MARK: - Initialization

    public init(dependencies: HouseholdMembersDependencies, householdId: String) {
        self.householdId = householdId
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("👥 HouseholdMembersViewModel initialized for household: \(householdId)")
    }

    public required init(dependencies: HouseholdMembersDependencies) {
        // This should not be used directly
        householdId = ""
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
    }

    public required init(dependencies: HouseholdMembersDependencies, initialState: State) {
        householdId = ""
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ HouseholdMembersViewModel appeared")
        await super.onAppear()

        await loadHouseholdAndMembers()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 HouseholdMembersViewModel refresh")
        await loadHouseholdAndMembers()
        await super.refresh()
    }

    // MARK: - Public Methods

    /// Load household information and members
    public func loadHouseholdAndMembers() async {
        await executeTask(.load) {
            await self.performLoadHouseholdAndMembers()
        }
    }

    /// Generate or refresh invite code
    public func generateInviteCode() async {
        await executeTask(.update) {
            await self.performGenerateInviteCode()
        }
    }

    /// Show invite sheet
    public func showInviteSheet() {
        updateState { $0.showingInviteSheet = true }

        if state.inviteCode.isEmpty {
            Task {
                await generateInviteCode()
            }
        }
    }

    /// Hide invite sheet
    public func hideInviteSheet() {
        updateState { $0.showingInviteSheet = false }
    }

    /// Show member actions for a specific member
    public func showMemberActions(for member: HouseholdMemberInfo) {
        guard canManageMembers && member.canBeRemoved else {
            Self.logger.warning("⚠️ Cannot show member actions - insufficient permissions")
            return
        }

        updateState {
            $0.selectedMemberId = member.id
            $0.showingMemberActions = true
        }
    }

    /// Hide member actions
    public func hideMemberActions() {
        updateState {
            $0.selectedMemberId = nil
            $0.showingMemberActions = false
        }
    }

    /// Change member role
    public func changeMemberRole(member: HouseholdMemberInfo, to newRole: MemberRole) async -> Bool {
        guard canManageMembers && member.canChangeRole else {
            Self.logger.warning("⚠️ Cannot change member role - insufficient permissions")
            return false
        }

        Self.logger.info("👥 Changing role for member \(member.displayName) to \(newRole.rawValue)")

        let householdId = self.householdId
        let dependencies = self.dependencies
        let userId = member.userId
        _ = member.id // Capture member ID for potential future use

        let result: Bool? = await executeTask(.update) {
            let _ = try await dependencies.householdService.updateMemberRole(
                householdId: householdId,
                userId: userId,
                role: newRole
            )
            let success = true

            if success {
                await MainActor.run {
                    // Update local member info
                    self.updateState { state in
                        if let index = state.members.firstIndex(where: { $0.id == member.id }) {
                            let updatedMember = HouseholdMemberInfo(
                                member: HouseholdMember(
                                    id: member.id,
                                    userId: member.userId,
                                    householdId: member.householdId,
                                    role: newRole,
                                    joinedAt: member.joinedAt
                                ),
                                user: member.user
                            )
                            state.members[index] = updatedMember
                        }
                    }

                    self.filterMembers()
                }
            }

            return success
        }

        return result == true
    }

    /// Show remove member confirmation
    public func showRemoveMemberConfirmation(for member: HouseholdMemberInfo) {
        guard canManageMembers && member.canBeRemoved else {
            Self.logger.warning("⚠️ Cannot remove member - insufficient permissions")
            return
        }

        updateState {
            $0.memberToRemove = member
            $0.showingRemoveMemberConfirmation = true
            $0.showingMemberActions = false
        }
    }

    /// Hide remove member confirmation
    public func hideRemoveMemberConfirmation() {
        updateState {
            $0.memberToRemove = nil
            $0.showingRemoveMemberConfirmation = false
        }
    }

    /// Remove member from household
    public func removeMember(_ member: HouseholdMemberInfo) async -> Bool {
        guard canManageMembers && member.canBeRemoved else {
            Self.logger.warning("⚠️ Cannot remove member - insufficient permissions")
            return false
        }

        Self.logger.info("🚪 Removing member: \(member.displayName)")

        let householdId = self.householdId
        let dependencies = self.dependencies
        let userId = member.userId
        _ = member.id // Capture member ID for potential future use

        let result: Bool? = await executeTask(.delete) {
            try await dependencies.householdService.removeMember(
                from: householdId,
                userId: userId
            )
            let success = true

            if success {
                await MainActor.run {
                    // Remove from local list
                    self.updateState { state in
                        state.members.removeAll { $0.id == member.id }
                        state.memberToRemove = nil
                        state.showingRemoveMemberConfirmation = false
                    }

                    self.filterMembers()
                }
            }

            return success
        }

        return result == true
    }

    /// Clear search
    public func clearSearch() {
        updateState {
            $0.searchText = ""
            $0.filteredMembers = []
        }
    }

    /// Dismiss error
    public func dismissError() {
        updateState {
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }

    // MARK: - Private Methods

    private func performLoadHouseholdAndMembers() async {
        Self.logger.info("📡 Loading household and members")

        updateState { $0.viewState = .loading }

        do {
            // Load household info
            let households = try await dependencies.householdService.getHouseholds()
            guard let household = households.first(where: { $0.id == householdId }) else {
                throw ViewModelError.householdNotFound
            }

            // Load detailed member information
            var memberInfos: [HouseholdMemberInfo] = []

            for member in household.members {
                do {
                    let user = try await dependencies.userService.getUser(id: member.userId)
                    let memberInfo = HouseholdMemberInfo(member: member, user: user)
                    memberInfos.append(memberInfo)
                } catch {
                    // If we can't load user info, create member info without user details
                    Self.logger.warning("⚠️ Could not load user info for member \(member.userId): \(error)")
                    let memberInfo = HouseholdMemberInfo(member: member, user: nil)
                    memberInfos.append(memberInfo)
                }
            }

            // Sort members by role (owner first, then admin, then members) and then by name
            memberInfos.sort { (lhs: HouseholdMemberInfo, rhs: HouseholdMemberInfo) in
                if lhs.role != rhs.role {
                    return lhs.role.sortOrder < rhs.role.sortOrder
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            updateState { state in
                state.household = household
                state.members = memberInfos
                state.viewState = memberInfos.isEmpty ? .empty : .loaded
            }

            filterMembers()
            Self.logger.info("✅ Loaded household '\(household.name)' with \(memberInfos.count) members")

        } catch {
            Self.logger.error("❌ Failed to load household and members: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    private func performGenerateInviteCode() async {
        Self.logger.info("🔗 Generating invite code")

        // For MVP, generate a simple invite code
        let inviteCode = "INVITE-\(UUID().uuidString.prefix(8))"

        updateState { state in
            state.inviteCode = inviteCode
        }

        Self.logger.info("✅ Invite code generated")
    }

    private func filterMembers() {
        guard !state.searchText.isEmpty else {
            updateState { $0.filteredMembers = [] }
            return
        }

        let searchText = state.searchText.lowercased()
        let filtered = state.members.filter { member in
            member.displayName.lowercased().contains(searchText) ||
                (member.user?.email?.lowercased().contains(searchText) ?? false)
        }

        updateState { $0.filteredMembers = filtered }
    }

    // MARK: - Error Handling Override

    override public func handleError(_ error: Error) {
        super.handleError(error)

        let errorMessage = error.localizedDescription
        updateState {
            $0.showingError = true
            $0.errorMessage = errorMessage
            $0.viewState = .error(currentError ?? .unknown(errorMessage))
        }
    }
}
