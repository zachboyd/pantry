import Foundation
import Observation

// MARK: - ListsTabViewModel

/// ViewModel for the Lists tab - manages shopping lists
@Observable @MainActor
public final class ListsTabViewModel: BaseReactiveViewModel<ListsTabViewModel.State, ListsTabDependencies> {
    private static let logger = Logger.shopping

    // MARK: - State

    public struct State: Sendable {
        var lists: [ShoppingList] = []
        var selectedHouseholdId: UUID?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var searchText = ""
        var filteredLists: [ShoppingList] = []
        var showingCreateListSheet = false
        var selectedListId: UUID?

        // Quick stats
        var totalLists = 0
        var completedLists = 0
        var totalItems = 0
        var completedItems = 0
    }

    // MARK: - Computed Properties

    public var lists: [ShoppingList] {
        state.lists
    }

    public var selectedHouseholdId: UUID? {
        state.selectedHouseholdId
    }

    public var searchText: String {
        get { state.searchText }
        set {
            updateState { $0.searchText = newValue }
            filterLists()
        }
    }

    public var displayedLists: [ShoppingList] {
        state.searchText.isEmpty ? state.lists : state.filteredLists
    }

    public var selectedListId: UUID? {
        get { state.selectedListId }
        set { updateState { $0.selectedListId = newValue } }
    }

    public var selectedList: ShoppingList? {
        guard let selectedId = state.selectedListId else { return nil }
        return state.lists.first { $0.id == selectedId }
    }

    public var isEmpty: Bool {
        state.lists.isEmpty
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

    public var showingCreateListSheet: Bool {
        get { state.showingCreateListSheet }
        set { updateState { $0.showingCreateListSheet = newValue } }
    }

    // Quick stats
    public var totalLists: Int {
        state.totalLists
    }

    public var completedLists: Int {
        state.completedLists
    }

    public var totalItems: Int {
        state.totalItems
    }

    public var completedItems: Int {
        state.completedItems
    }

    public var completionPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    // MARK: - Initialization

    public required init(dependencies: ListsTabDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("📝 ListsTabViewModel initialized")

        setupHouseholdObservation()
    }

    public required init(dependencies: ListsTabDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
        setupHouseholdObservation()
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ ListsTabViewModel appeared")
        await super.onAppear()

        await loadSelectedHousehold()

        if let householdId = state.selectedHouseholdId {
            await loadShoppingLists(for: householdId)
        }
    }

    override public func refresh() async {
        Self.logger.debug("🔄 ListsTabViewModel refresh")

        if let householdId = state.selectedHouseholdId {
            await loadShoppingLists(for: householdId)
        }

        await super.refresh()
    }

    // MARK: - Public Methods

    /// Load shopping lists for a specific household
    public func loadShoppingLists(for householdId: UUID) async {
        await executeTask(.load) { [weak self] in
            guard let self else { return }
            await performLoadShoppingLists(for: householdId)
        }
    }

    /// Create a new shopping list
    public func createList(name: String) async -> Bool {
        guard let householdId = state.selectedHouseholdId else {
            Self.logger.warning("⚠️ Cannot create list - no household selected")
            return false
        }

        Self.logger.info("📝 Creating shopping list: \(name)")

        let result: ShoppingList? = await executeTask(.create) { [weak self] in
            guard let self else { throw ViewModelError.unknown("Self reference lost") }
            let list = try await dependencies.shoppingListService.createList(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                householdId: householdId,
            )

            await MainActor.run {
                // Add to local list
                self.updateState { state in
                    state.lists.append(list)
                    state.selectedListId = list.id
                }

                self.updateStats()
                self.filterLists()
            }

            return list
        }

        return result != nil
    }

    /// Delete a shopping list
    public func deleteList(_ list: ShoppingList) async -> Bool {
        Self.logger.info("🗑️ Deleting shopping list: \(list.name)")

        let result: Bool? = await executeTask(.delete) { [weak self] in
            guard let self else { return false }
            // This would be implemented in the shopping list service
            // For now, simulate success
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

            await MainActor.run {
                // Remove from local list
                self.updateState { state in
                    state.lists.removeAll { $0.id == list.id }

                    // Clear selection if this was the selected list
                    if state.selectedListId == list.id {
                        state.selectedListId = nil
                    }
                }

                self.updateStats()
                self.filterLists()
            }

            return true
        }

        return result == true
    }

    /// Add item to a shopping list
    public func addItem(to listId: UUID, item: ShoppingListItem) async -> Bool {
        Self.logger.info("➕ Adding item to list: \(item.name)")

        let result: Void? = await executeTask(.addItem) { [weak self] in
            guard let self else { return }
            try await dependencies.shoppingListService.addItem(to: listId, item: item)

            await MainActor.run {
                // Update local list
                self.updateState { state in
                    if let index = state.lists.firstIndex(where: { $0.id == listId }) {
                        let updatedList = state.lists[index]
                        var updatedItems = updatedList.items
                        updatedItems.append(item)

                        // Create updated list (since ShoppingList is likely immutable)
                        let newList = ShoppingList(
                            id: updatedList.id,
                            householdId: updatedList.householdId,
                            name: updatedList.name,
                            items: updatedItems,
                            createdBy: updatedList.createdBy,
                            createdAt: updatedList.createdAt,
                            updatedAt: Date(),
                        )

                        state.lists[index] = newList
                    }
                }

                self.updateStats()
                self.filterLists()
            }
        }

        return result != nil
    }

    /// Remove item from a shopping list
    public func removeItem(from listId: UUID, itemId: UUID) async -> Bool {
        Self.logger.info("🗑️ Removing item from list")

        let result: Void? = await executeTask(.removeItem) { [weak self] in
            guard let self else { return }
            try await dependencies.shoppingListService.removeItem(from: listId, itemId: itemId)

            await MainActor.run {
                // Update local list
                self.updateState { state in
                    if let index = state.lists.firstIndex(where: { $0.id == listId }) {
                        let updatedList = state.lists[index]
                        let updatedItems = updatedList.items.filter { $0.id != itemId }

                        // Create updated list
                        let newList = ShoppingList(
                            id: updatedList.id,
                            householdId: updatedList.householdId,
                            name: updatedList.name,
                            items: updatedItems,
                            createdBy: updatedList.createdBy,
                            createdAt: updatedList.createdAt,
                            updatedAt: Date(),
                        )

                        state.lists[index] = newList
                    }
                }

                self.updateStats()
                self.filterLists()
            }
        }

        return result != nil
    }

    /// Toggle item completion status
    public func toggleItemCompletion(_ item: ShoppingListItem, in listId: UUID) async -> Bool {
        Self.logger.info("✅ Toggling item completion: \(item.name)")

        // Create updated item with toggled completion status
        let updatedItem = ShoppingListItem(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            isCompleted: !item.isCompleted,
            addedBy: item.addedBy,
            completedBy: item.isCompleted ? nil : UUID(uuidString: "00000000-0000-0000-0000-000000000001"), // This would be actual user ID
            completedAt: item.isCompleted ? nil : Date(),
        )

        let result: Bool? = await executeTask(.updateQuantity) { [weak self] in
            guard let self else { return false }
            // This would update the item through the service
            // For now, just update locally
            await MainActor.run {
                self.updateState { state in
                    if let listIndex = state.lists.firstIndex(where: { $0.id == listId }),
                       let itemIndex = state.lists[listIndex].items.firstIndex(where: { $0.id == item.id })
                    {
                        let updatedList = state.lists[listIndex]
                        var updatedItems = updatedList.items
                        updatedItems[itemIndex] = updatedItem

                        // Create updated list
                        let newList = ShoppingList(
                            id: updatedList.id,
                            householdId: updatedList.householdId,
                            name: updatedList.name,
                            items: updatedItems,
                            createdBy: updatedList.createdBy,
                            createdAt: updatedList.createdAt,
                            updatedAt: Date(),
                        )

                        state.lists[listIndex] = newList
                    }
                }

                self.updateStats()
                self.filterLists()
            }

            return true
        }

        return result == true
    }

    /// Show create list sheet
    public func showCreateListSheet() {
        guard state.selectedHouseholdId != nil else {
            Self.logger.warning("⚠️ Cannot create list - no household selected")
            updateState {
                $0.showingError = true
                $0.errorMessage = L("error.no_household_selected")
            }
            return
        }

        updateState { $0.showingCreateListSheet = true }
    }

    /// Hide create list sheet
    public func hideCreateListSheet() {
        updateState { $0.showingCreateListSheet = false }
    }

    /// Clear search
    public func clearSearch() {
        updateState {
            $0.searchText = ""
            $0.filteredLists = []
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

    private func setupHouseholdObservation() {
        // This would typically observe household changes from a service or coordinator
        // For now, we'll load the selected household from UserDefaults
        if let selectedIdString = UserDefaults.standard.string(forKey: "selectedHouseholdId"),
           let selectedId = UUID(uuidString: selectedIdString)
        {
            updateState { $0.selectedHouseholdId = selectedId }
        }
    }

    private func loadSelectedHousehold() async {
        // Check for currently selected household
        let selectedIdString = UserDefaults.standard.string(forKey: "selectedHouseholdId")
        let selectedId = selectedIdString.flatMap { UUID(uuidString: $0) }

        if selectedId != state.selectedHouseholdId {
            updateState { $0.selectedHouseholdId = selectedId }
            Self.logger.info("🏠 Selected household changed to: \(selectedId?.uuidString ?? "none")")
        }
    }

    private func performLoadShoppingLists(for householdId: UUID) async {
        Self.logger.info("📡 Loading shopping lists for household: \(householdId)")

        updateState { $0.viewState = .loading }

        do {
            let lists = try await dependencies.shoppingListService.getLists(for: householdId)

            updateState { state in
                state.lists = lists
                state.viewState = lists.isEmpty ? .empty : .loaded

                // Auto-select first list if none selected
                if state.selectedListId == nil, let firstList = lists.first {
                    state.selectedListId = firstList.id
                }
            }

            updateStats()
            filterLists()
            Self.logger.info("✅ Loaded \(lists.count) shopping lists")

        } catch {
            Self.logger.error("❌ Failed to load shopping lists: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    private func updateStats() {
        let lists = state.lists
        var totalItems = 0
        var completedItems = 0
        var completedLists = 0

        for list in lists {
            let listItemCount = list.items.count
            let listCompletedCount = list.items.count(where: { $0.isCompleted })

            totalItems += listItemCount
            completedItems += listCompletedCount

            // Consider a list completed if all items are completed
            if listItemCount > 0, listCompletedCount == listItemCount {
                completedLists += 1
            }
        }

        updateState { state in
            state.totalLists = lists.count
            state.completedLists = completedLists
            state.totalItems = totalItems
            state.completedItems = completedItems
        }
    }

    private func filterLists() {
        guard !state.searchText.isEmpty else {
            updateState { $0.filteredLists = [] }
            return
        }

        let searchText = state.searchText.lowercased()
        let filtered = state.lists.filter { list in
            list.name.lowercased().contains(searchText) ||
                list.items.contains { $0.name.lowercased().contains(searchText) }
        }

        updateState { $0.filteredLists = filtered }
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

public extension ListsTabViewModel {
    /// Get active (incomplete) lists
    func getActiveLists() -> [ShoppingList] {
        state.lists.filter { list in
            !list.items.isEmpty && list.items.contains { !$0.isCompleted }
        }
    }

    /// Get completed lists
    func getCompletedLists() -> [ShoppingList] {
        state.lists.filter { list in
            !list.items.isEmpty && list.items.allSatisfy(\.isCompleted)
        }
    }

    /// Get lists by creation date
    func getRecentLists(limit: Int = 5) -> [ShoppingList] {
        Array(state.lists.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    /// Get completion percentage for a specific list
    func getCompletionPercentage(for list: ShoppingList) -> Double {
        guard !list.items.isEmpty else { return 0 }
        let completedCount = list.items.count(where: { $0.isCompleted })
        return Double(completedCount) / Double(list.items.count)
    }
}
