import Foundation
import Observation

// MARK: - HouseholdListViewModel

/// ViewModel for managing household list display and selection
@Observable @MainActor
public final class HouseholdListViewModel: BaseReactiveViewModel<HouseholdListViewModel.State, HouseholdListDependencies> {
    private static let logger = Logger.household

    // MARK: - Watched Data

    /// Watched household list that updates reactively
    public let householdsWatch: WatchedResult<[Household]>

    // MARK: - State

    public struct State: Sendable {
        var households: [Household] = []
        var selectedHouseholdId: UUID?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var searchText = ""
        var filteredHouseholds: [Household] = []
    }

    // MARK: - Computed Properties

    public var households: [Household] {
        // Use watched data if available, otherwise fall back to state
        householdsWatch.value ?? state.households
    }

    public var selectedHouseholdId: UUID? {
        state.selectedHouseholdId
    }

    public var selectedHousehold: Household? {
        guard let selectedId = state.selectedHouseholdId else { return nil }
        return state.households.first { $0.id == selectedId }
    }

    public var searchText: String {
        get { state.searchText }
        set {
            updateState { $0.searchText = newValue }
            filterHouseholds()
        }
    }

    public var filteredHouseholds: [Household] {
        state.filteredHouseholds
    }

    public var displayedHouseholds: [Household] {
        state.searchText.isEmpty ? state.households : state.filteredHouseholds
    }

    public var isEmpty: Bool {
        state.households.isEmpty
    }

    public var isLoading: Bool {
        loadingStates.isAnyLoading || householdsWatch.isLoading
    }

    public var showingError: Bool {
        state.showingError
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    // MARK: - Initialization

    public required init(dependencies: HouseholdListDependencies) {
        // Start watching households immediately
        householdsWatch = dependencies.householdService.watchUserHouseholds()

        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)

        // Register watch for automatic cleanup
        registerWatch(householdsWatch)

        Self.logger.info("🏠 HouseholdListViewModel initialized")

        // Update state when watched data changes
        Task { @MainActor in
            await self.observeHouseholds()
        }
    }

    public required init(dependencies: HouseholdListDependencies, initialState: State) {
        // Start watching households immediately
        householdsWatch = dependencies.householdService.watchUserHouseholds()

        super.init(dependencies: dependencies, initialState: initialState)

        // Register watch for automatic cleanup
        registerWatch(householdsWatch)

        // Update state when watched data changes
        Task { @MainActor in
            await self.observeHouseholds()
        }
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ HouseholdListViewModel appeared")
        await super.onAppear()

        // No need to load manually - watched data will provide updates
        // Just update state from watched data if available
        if let households = householdsWatch.value {
            updateState { state in
                state.households = households
                state.viewState = households.isEmpty ? .empty : .loaded

                // Restore selected household from UserDefaults
                if let savedSelectedIdString = UserDefaults.standard.string(forKey: "selectedHouseholdId"),
                   let savedSelectedId = UUID(uuidString: savedSelectedIdString),
                   households.contains(where: { $0.id == savedSelectedId })
                {
                    state.selectedHouseholdId = savedSelectedId
                } else if let firstHousehold = households.first {
                    // Auto-select first household if none was previously selected
                    state.selectedHouseholdId = firstHousehold.id
                    UserDefaults.standard.set(firstHousehold.id.uuidString, forKey: "selectedHouseholdId")
                }
            }
            filterHouseholds()
        }
    }

    override public func refresh() async {
        Self.logger.debug("🔄 HouseholdListViewModel refresh")
        // Refresh is handled by Apollo's cache policy - no manual refresh needed
        // But we can force a refetch if needed
        if householdsWatch.error != nil {
            await householdsWatch.retry()
        }
        await super.refresh()
    }

    // MARK: - Public Methods

    /// Load all households for the current user
    public func loadHouseholds() async {
        await executeTask(.load) {
            await self.performLoadHouseholds()
        }
    }

    /// Select a household
    public func selectHousehold(_ household: Household) {
        Self.logger.info("🏠 Selecting household: \(household.name)")

        updateState { $0.selectedHouseholdId = household.id }

        // Persist the selection
        UserDefaults.standard.set(household.id.uuidString, forKey: "selectedHouseholdId")
    }

    /// Deselect current household
    public func deselectHousehold() {
        Self.logger.info("🏠 Deselecting household")

        updateState { $0.selectedHouseholdId = nil }

        // Clear the persisted selection
        UserDefaults.standard.removeObject(forKey: "selectedHouseholdId")
    }

    /// Create a new household
    public func createHousehold(name: String, description: String? = nil) async -> Bool {
        Self.logger.info("🏗️ Creating household: \(name)")

        let result: Household? = await executeTask(.create) {
            let household = try await self.dependencies.householdService.createHousehold(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            )

            await MainActor.run {
                // Add to local list
                self.updateState { state in
                    state.households.append(household)
                    state.selectedHouseholdId = household.id
                }

                // Persist the selection
                UserDefaults.standard.set(household.id, forKey: "selectedHouseholdId")
            }

            return household
        }

        return result != nil
    }

    /// Join a household using invite code
    public func joinHousehold(inviteCode: String) async -> Bool {
        Self.logger.info("🤝 Joining household with invite code")

        let result: Household? = await executeTask(.update) {
            let household = try await self.dependencies.householdService.joinHousehold(inviteCode: inviteCode)

            await MainActor.run {
                // Add to local list if not already present
                self.updateState { state in
                    if !state.households.contains(where: { $0.id == household.id }) {
                        state.households.append(household)
                    }
                    state.selectedHouseholdId = household.id
                }

                // Persist the selection
                UserDefaults.standard.set(household.id, forKey: "selectedHouseholdId")
            }

            return household
        }

        return result != nil
    }

    /// Leave a household
    public func leaveHousehold(_ household: Household) async -> Bool {
        Self.logger.info("🚪 Leaving household: \(household.name)")

        // TODO: Implement when leaveHousehold is added to HouseholdServiceProtocol
        Self.logger.warning("⚠️ leaveHousehold not yet implemented in service")
        return false

        /*
         let result: Bool? = await executeTask(.delete) {
             let success = try await self.dependencies.householdService.leaveHousehold(householdId: household.id)

             if success {
                 await MainActor.run {
                     // Remove from local list
                     self.updateState { state in
                         state.households.removeAll { $0.id == household.id }

                         // If this was the selected household, clear selection
                         if state.selectedHouseholdId == household.id {
                             state.selectedHouseholdId = nil
                         }
                     }

                     // Clear persisted selection if needed
                     let selectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId")
                     if selectedId == household.id {
                         UserDefaults.standard.removeObject(forKey: "selectedHouseholdId")
                     }
                 }
             }

             return success
         }

         return result == true
         */
    }

    /// Delete a household (owner only)
    public func deleteHousehold(_ household: Household) async -> Bool {
        Self.logger.info("🗑️ Deleting household: \(household.name)")

        // TODO: Implement when deleteHousehold is added to HouseholdServiceProtocol
        Self.logger.warning("⚠️ deleteHousehold not yet implemented in service")
        return false

        /*
         let result: Bool? = await executeTask(.delete) {
             let success = try await self.dependencies.householdService.deleteHousehold(householdId: household.id)

             if success {
                 await MainActor.run {
                     // Remove from local list
                     self.updateState { state in
                         state.households.removeAll { $0.id == household.id }

                         // If this was the selected household, clear selection
                         if state.selectedHouseholdId == household.id {
                             state.selectedHouseholdId = nil
                         }
                     }

                     // Clear persisted selection if needed
                     let selectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId")
                     if selectedId == household.id {
                         UserDefaults.standard.removeObject(forKey: "selectedHouseholdId")
                     }
                 }
             }

             return success
         }

         return result == true
         */
    }

    /// Clear search text
    public func clearSearch() {
        updateState {
            $0.searchText = ""
            $0.filteredHouseholds = []
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

    private func performLoadHouseholds() async {
        Self.logger.info("📡 Loading households")

        updateState { $0.viewState = .loading }

        do {
            let households = try await dependencies.householdService.getHouseholds()

            updateState { state in
                state.households = households
                state.viewState = households.isEmpty ? .empty : .loaded

                // Restore selected household from UserDefaults
                if let savedSelectedIdString = UserDefaults.standard.string(forKey: "selectedHouseholdId"),
                   let savedSelectedId = UUID(uuidString: savedSelectedIdString),
                   households.contains(where: { $0.id == savedSelectedId })
                {
                    state.selectedHouseholdId = savedSelectedId
                } else if let firstHousehold = households.first {
                    // Auto-select first household if none was previously selected
                    state.selectedHouseholdId = firstHousehold.id
                    UserDefaults.standard.set(firstHousehold.id.uuidString, forKey: "selectedHouseholdId")
                }
            }

            filterHouseholds()
            Self.logger.info("✅ Loaded \(households.count) households")

        } catch {
            Self.logger.error("❌ Failed to load households: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    private func filterHouseholds() {
        guard !state.searchText.isEmpty else {
            updateState { $0.filteredHouseholds = [] }
            return
        }

        let searchText = state.searchText.lowercased()
        let filtered = state.households.filter { household in
            household.name.lowercased().contains(searchText)
        }

        updateState { $0.filteredHouseholds = filtered }
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

    // MARK: - Private Methods (Reactive)

    /// Observe changes to the household list
    private func observeHouseholds() async {
        // The WatchedResult is @Observable, so changes will trigger UI updates automatically
        // We just need to sync the watched data with our local state for filtering
        if let households = householdsWatch.value {
            updateState { state in
                state.households = households
                state.viewState = households.isEmpty ? .empty : .loaded
            }
            filterHouseholds()
        }
    }

    // MARK: - WatchedResult Helpers Override

    override public var isWatchedDataLoading: Bool {
        householdsWatch.isLoading
    }

    override public var watchedDataError: Error? {
        householdsWatch.error
    }

    override public func retryFailedWatches() async {
        if householdsWatch.error != nil {
            await householdsWatch.retry()
        }
    }
}

// MARK: - Helper Extensions

public extension HouseholdListViewModel {
    /// Check if user is the owner of a household
    func isOwner(of household: Household) -> Bool {
        guard let currentUserId = dependencies.authService.currentUser?.id else {
            return false
        }
        return household.createdBy == currentUserId
    }

    /// Check if user can delete a household
    func canDelete(_ household: Household) -> Bool {
        isOwner(of: household)
    }

    /// Check if user can leave a household
    func canLeave(_ household: Household) -> Bool {
        // Can always leave if not the owner, owners need to transfer ownership first
        !isOwner(of: household)
    }
}
