import Foundation
import Observation

// MARK: - JeevesTabViewModel

/// ViewModel for the Jeeves tab - manages pantry items and inventory
@Observable @MainActor
public final class JeevesTabViewModel: BaseReactiveViewModel<JeevesTabViewModel.State, JeevesTabDependencies> {
    private static let logger = Logger.jeeves

    // MARK: - State

    public struct State: Sendable {
        var items: [Item] = []
        var selectedHouseholdId: LowercaseUUID?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var searchText = ""
        var filteredItems: [Item] = []
        var selectedCategory: ItemCategory?
        var sortOption: ItemSortOption = .name
        var showingAddItemSheet = false
        var showingFilterSheet = false

        // Quick stats
        var totalItems = 0
        var expiringItems = 0
        var expiredItems = 0
        var categoryCounts: [ItemCategory: Int] = [:]
    }

    /// Sort options for pantry items
    public enum ItemSortOption: String, CaseIterable, Sendable {
        case name
        case category
        case expirationDate = "expiration"
        case dateAdded = "added"

        public var displayName: String {
            switch self {
            case .name: "Name"
            case .category: "Category"
            case .expirationDate: "Expiration Date"
            case .dateAdded: "Date Added"
            }
        }
    }

    // MARK: - Computed Properties

    public var items: [Item] {
        state.items
    }

    public var selectedHouseholdId: LowercaseUUID? {
        state.selectedHouseholdId
    }

    public var searchText: String {
        get { state.searchText }
        set {
            updateState { $0.searchText = newValue }
            filterAndSortItems()
        }
    }

    public var selectedCategory: ItemCategory? {
        get { state.selectedCategory }
        set {
            updateState { $0.selectedCategory = newValue }
            filterAndSortItems()
        }
    }

    public var sortOption: ItemSortOption {
        get { state.sortOption }
        set {
            updateState { $0.sortOption = newValue }
            filterAndSortItems()
        }
    }

    public var displayedItems: [Item] {
        state.searchText.isEmpty && state.selectedCategory == nil ? state.items : state.filteredItems
    }

    public var isEmpty: Bool {
        state.items.isEmpty
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

    public var showingAddItemSheet: Bool {
        get { state.showingAddItemSheet }
        set { updateState { $0.showingAddItemSheet = newValue } }
    }

    public var showingFilterSheet: Bool {
        get { state.showingFilterSheet }
        set { updateState { $0.showingFilterSheet = newValue } }
    }

    // Quick stats
    public var totalItems: Int {
        state.totalItems
    }

    public var expiringItems: Int {
        state.expiringItems
    }

    public var expiredItems: Int {
        state.expiredItems
    }

    public var categoryCounts: [ItemCategory: Int] {
        state.categoryCounts
    }

    // MARK: - Initialization

    public required init(dependencies: JeevesTabDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("🥫 JeevesTabViewModel initialized")
    }

    public required init(dependencies: JeevesTabDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ JeevesTabViewModel appeared")
        await super.onAppear()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 JeevesTabViewModel refresh")

        if let householdId = state.selectedHouseholdId {
            await loadItems(for: householdId)
        }

        await super.refresh()
    }

    // MARK: - Public Methods

    /// Set the current household
    public func setHousehold(_ household: Household?) {
        let newHouseholdId = household?.id
        guard newHouseholdId != state.selectedHouseholdId else { return }

        Self.logger.info("🏠 Setting household to: \(household?.name ?? "none")")
        updateState {
            $0.selectedHouseholdId = newHouseholdId
            // Clear items when household changes
            $0.items = []
            $0.filteredItems = []
            $0.totalItems = 0
            $0.expiringItems = 0
            $0.expiredItems = 0
            $0.categoryCounts = [:]
        }

        // Load items for new household
        if let householdId = newHouseholdId {
            Task {
                await loadItems(for: householdId)
            }
        }
    }

    /// Load pantry items for a specific household
    public func loadItems(for householdId: LowercaseUUID) async {
        await executeTask(.load) {
            await self.performLoadItems(for: householdId)
        }
    }

    /// Add a new pantry item
    public func addItem(_ item: Item) async -> Bool {
        Self.logger.info("➕ Adding pantry item: \(item.name)")

        let result: Void? = await executeTask(.addItem) {
            try await self.dependencies.itemService.addItem(item)

            await MainActor.run {
                // Add to local list
                self.updateState { state in
                    state.items.append(item)
                }

                self.updateStats()
                self.filterAndSortItems()
            }
        }

        return result != nil
    }

    /// Update an existing pantry item
    public func updateItem(_ item: Item) async -> Bool {
        Self.logger.info("✏️ Updating pantry item: \(item.name)")

        let result: Void? = await executeTask(.updateQuantity) {
            try await self.dependencies.itemService.updateItem(item)

            await MainActor.run {
                // Update in local list
                self.updateState { state in
                    if let index = state.items.firstIndex(where: { $0.id == item.id }) {
                        state.items[index] = item
                    }
                }

                self.updateStats()
                self.filterAndSortItems()
            }
        }

        return result != nil
    }

    /// Remove a pantry item
    public func removeItem(_ item: Item) async -> Bool {
        Self.logger.info("🗑️ Removing pantry item: \(item.name)")

        let result: Void? = await executeTask(.removeItem) {
            try await self.dependencies.itemService.deleteItem(id: item.id)

            await MainActor.run {
                // Remove from local list
                self.updateState { state in
                    state.items.removeAll { $0.id == item.id }
                }

                self.updateStats()
                self.filterAndSortItems()
            }
        }

        return result != nil
    }

    /// Show add item sheet
    public func showAddItemSheet() {
        guard state.selectedHouseholdId != nil else {
            Self.logger.warning("⚠️ Cannot add item - no household selected")
            updateState {
                $0.showingError = true
                $0.errorMessage = L("error.no_household_selected")
            }
            return
        }

        updateState { $0.showingAddItemSheet = true }
    }

    /// Hide add item sheet
    public func hideAddItemSheet() {
        updateState { $0.showingAddItemSheet = false }
    }

    /// Show filter sheet
    public func showFilterSheet() {
        updateState { $0.showingFilterSheet = true }
    }

    /// Hide filter sheet
    public func hideFilterSheet() {
        updateState { $0.showingFilterSheet = false }
    }

    /// Clear all filters
    public func clearFilters() {
        updateState {
            $0.searchText = ""
            $0.selectedCategory = nil
        }
        filterAndSortItems()
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

    private func performLoadItems(for householdId: LowercaseUUID) async {
        Self.logger.info("📡 Loading pantry items for household: \(householdId)")

        updateState { $0.viewState = .loading }

        do {
            let items = try await dependencies.itemService.getItems(for: householdId)

            updateState { state in
                state.items = items
                state.viewState = items.isEmpty ? .empty : .loaded
            }

            updateStats()
            filterAndSortItems()
            Self.logger.info("✅ Loaded \(items.count) pantry items")

        } catch {
            Self.logger.error("❌ Failed to load pantry items: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    private func updateStats() {
        let items = state.items
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        var categoryCounts: [ItemCategory: Int] = [:]
        var expiringCount = 0
        var expiredCount = 0

        for item in items {
            // Update category counts
            categoryCounts[item.category, default: 0] += 1

            // Check expiration status
            if let expirationDate = item.expirationDate {
                if expirationDate < now {
                    expiredCount += 1
                } else if expirationDate < weekFromNow {
                    expiringCount += 1
                }
            }
        }

        updateState { state in
            state.totalItems = items.count
            state.expiringItems = expiringCount
            state.expiredItems = expiredCount
            state.categoryCounts = categoryCounts
        }
    }

    private func filterAndSortItems() {
        var filteredItems = state.items

        // Apply search filter
        if !state.searchText.isEmpty {
            let searchText = state.searchText.lowercased()
            filteredItems = filteredItems.filter { item in
                item.name.lowercased().contains(searchText) ||
                    item.notes?.lowercased().contains(searchText) == true ||
                    item.location?.lowercased().contains(searchText) == true
            }
        }

        // Apply category filter
        if let selectedCategory = state.selectedCategory {
            filteredItems = filteredItems.filter { $0.category == selectedCategory }
        }

        // Apply sorting
        switch state.sortOption {
        case .name:
            filteredItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .category:
            filteredItems.sort { lhs, rhs in
                if lhs.category != rhs.category {
                    return lhs.category.rawValue < rhs.category.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .expirationDate:
            filteredItems.sort { lhs, rhs in
                guard let lhsDate = lhs.expirationDate else { return false }
                guard let rhsDate = rhs.expirationDate else { return true }
                return lhsDate < rhsDate
            }
        case .dateAdded:
            filteredItems.sort { $0.createdAt > $1.createdAt }
        }

        updateState { $0.filteredItems = filteredItems }
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

public extension JeevesTabViewModel {
    /// Get items expiring within a certain number of days
    func getItemsExpiring(within days: Int) -> [Item] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return state.items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return expirationDate <= cutoffDate && expirationDate >= Date()
        }
    }

    /// Get expired items
    func getExpiredItems() -> [Item] {
        let now = Date()
        return state.items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return expirationDate < now
        }
    }

    /// Get items by category
    func getItems(in category: ItemCategory) -> [Item] {
        state.items.filter { $0.category == category }
    }
}
