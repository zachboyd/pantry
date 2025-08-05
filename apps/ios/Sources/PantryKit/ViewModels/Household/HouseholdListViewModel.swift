import Foundation
import Observation

// MARK: - HouseholdListViewModel

/// ViewModel for managing household list display and selection
@Observable @MainActor
public final class HouseholdListViewModel: BaseReactiveViewModel<HouseholdListViewModel.State, HouseholdListDependencies> {
    private static let logger = Logger.household

    // MARK: - State

    public struct State: Sendable {
        var households: [Household] = []
        var selectedHouseholdId: String?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var searchText = ""
        var filteredHouseholds: [Household] = []
    }

    // MARK: - Computed Properties

    public var households: [Household] {
        state.households
    }

    public var selectedHouseholdId: String? {
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
        loadingStates.isAnyLoading
    }

    public var showingError: Bool {
        state.showingError
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    // MARK: - Initialization

    public required init(dependencies: HouseholdListDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("🏠 HouseholdListViewModel initialized")
    }

    public required init(dependencies: HouseholdListDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ HouseholdListViewModel appeared")
        await super.onAppear()

        if state.households.isEmpty {
            await loadHouseholds()
        }
    }

    override public func refresh() async {
        Self.logger.debug("🔄 HouseholdListViewModel refresh")
        await loadHouseholds()
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
        UserDefaults.standard.set(household.id, forKey: "selectedHouseholdId")
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
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines)
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
                if let savedSelectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId"),
                   households.contains(where: { $0.id == savedSelectedId })
                {
                    state.selectedHouseholdId = savedSelectedId
                } else if let firstHousehold = households.first {
                    // Auto-select first household if none was previously selected
                    state.selectedHouseholdId = firstHousehold.id
                    UserDefaults.standard.set(firstHousehold.id, forKey: "selectedHouseholdId")
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
        return isOwner(of: household)
    }

    /// Check if user can leave a household
    func canLeave(_ household: Household) -> Bool {
        // Can always leave if not the owner, owners need to transfer ownership first
        return !isOwner(of: household)
    }
}
