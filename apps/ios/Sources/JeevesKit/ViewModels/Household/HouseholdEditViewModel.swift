import Foundation
import Observation

// MARK: - HouseholdEditViewModel

/// ViewModel for creating and editing households
@Observable @MainActor
public final class HouseholdEditViewModel: BaseReactiveViewModel<HouseholdEditViewModel.State, HouseholdEditDependencies> {
    private static let logger = Logger.household

    // MARK: - State

    public struct State: Sendable {
        var name = ""
        var description = ""
        var mode: HouseholdEditMode = .create
        var householdId: String?
        var originalHousehold: Household?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var showingComingSoon = false
        var isReadOnly = false

        // Form validation
        var nameError: String?
        var descriptionError: String?
        var hasUnsavedChanges = false
    }

    // MARK: - Computed Properties

    public var name: String {
        get { state.name }
        set {
            updateState {
                $0.name = newValue
                // Only mark as changed if actually different from original
                if let original = $0.originalHousehold {
                    $0.hasUnsavedChanges = (newValue != original.name || $0.description != (original.description ?? ""))
                } else {
                    $0.hasUnsavedChanges = true
                }
            }
            validateName()
        }
    }

    public var description: String {
        get { state.description }
        set {
            updateState {
                $0.description = newValue
                // Only mark as changed if actually different from original
                if let original = $0.originalHousehold {
                    $0.hasUnsavedChanges = ($0.name != original.name || newValue != (original.description ?? ""))
                } else {
                    $0.hasUnsavedChanges = true
                }
            }
        }
    }

    public var mode: HouseholdEditMode {
        state.mode
    }

    public var householdId: String? {
        state.householdId
    }

    public var isCreateMode: Bool {
        state.mode == .create
    }

    public var isEditMode: Bool {
        state.mode == .edit
    }

    public var canSave: Bool {
        !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            state.nameError == nil &&
            state.descriptionError == nil &&
            !loadingStates.isLoading(.save) &&
            (!isEditMode || state.hasUnsavedChanges)
    }

    public var showLoadingIndicator: Bool {
        loadingStates.isAnyLoading
    }

    public var title: String {
        isCreateMode ? "Create Household" : "Edit Household"
    }

    public var saveButtonTitle: String {
        isCreateMode ? "Create" : "Save Changes"
    }

    public var nameError: String? {
        state.nameError
    }

    public var descriptionError: String? {
        state.descriptionError
    }

    public var showingError: Bool {
        state.showingError
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    public var hasUnsavedChanges: Bool {
        state.hasUnsavedChanges
    }

    public var showingComingSoon: Bool {
        state.showingComingSoon
    }

    public var isReadOnly: Bool {
        state.isReadOnly
    }

    // MARK: - Initialization

    public init(
        dependencies: HouseholdEditDependencies,
        householdId: String? = nil,
        mode: HouseholdEditMode = .create,
        isReadOnly: Bool = false
    ) {
        let initialState = State(
            mode: mode,
            householdId: householdId,
            isReadOnly: isReadOnly
        )
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("🏠 HouseholdEditViewModel initialized - Mode: \(mode), ReadOnly: \(isReadOnly)")
    }

    public required init(dependencies: HouseholdEditDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
    }

    public required init(dependencies: HouseholdEditDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ HouseholdEditViewModel appeared")
        await super.onAppear()

        if isEditMode, let householdId = state.householdId {
            await loadHousehold(id: householdId)

            // Check if user has permission to edit this household
            if let currentUserId = dependencies.authService.currentUser?.id {
                // For now, determine read-only based on whether they can manage the household
                // This could be enhanced with proper permission checks
                let canEdit = await checkEditPermission(for: householdId, userId: currentUserId)
                updateState { $0.isReadOnly = !canEdit }
            }
        }
    }

    override public func refresh() async {
        Self.logger.debug("🔄 HouseholdEditViewModel refresh")

        if isEditMode, let householdId = state.householdId {
            await loadHousehold(id: householdId)
        }

        await super.refresh()
    }

    // MARK: - Public Methods

    /// Save the household (create or update)
    public func save() async -> Bool {
        guard canSave else {
            Self.logger.warning("⚠️ Cannot save - requirements not met")
            return false
        }

        if isCreateMode {
            return await createHousehold()
        } else {
            return await updateHousehold()
        }
    }

    /// Load household data for editing
    public func loadHousehold(id: String) async {
        await executeTask(.load) { [weak self] in
            guard let self = self else { return }
            await self.performLoadHousehold(id: id)
        }
    }

    /// Reset form to original state
    public func resetForm() {
        if let original = state.originalHousehold {
            updateState {
                $0.name = original.name
                $0.description = original.description ?? ""
                $0.hasUnsavedChanges = false
                $0.nameError = nil
                $0.descriptionError = nil
            }
        } else {
            clearForm()
        }

        Self.logger.info("🔄 Form reset to original state")
    }

    /// Clear all form data
    public func clearForm() {
        updateState {
            $0.name = ""
            $0.description = ""
            $0.hasUnsavedChanges = false
            $0.nameError = nil
            $0.descriptionError = nil
            $0.showingError = false
            $0.errorMessage = nil
            $0.showingComingSoon = false
        }
        clearError()

        Self.logger.info("🧹 Form cleared")
    }

    /// Validate household name
    public func validateName() {
        updateState { $0.nameError = nil }

        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            updateState { $0.nameError = "Household name is required" }
            return
        }

        if trimmedName.count < 2 {
            updateState { $0.nameError = "Household name must be at least 2 characters" }
            return
        }

        if trimmedName.count > 50 {
            updateState { $0.nameError = "Household name must be no more than 50 characters" }
            return
        }
    }

    /// Validate description
    public func validateDescription() {
        updateState { $0.descriptionError = nil }

        let trimmedDescription = state.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedDescription.count > 200 {
            updateState { $0.descriptionError = "Description must be no more than 200 characters" }
        }
    }

    /// Validate all form fields
    public func validateForm() -> Bool {
        validateName()
        validateDescription()

        return state.nameError == nil && state.descriptionError == nil
    }

    /// Dismiss error
    public func dismissError() {
        updateState {
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }

    /// Dismiss coming soon alert
    public func dismissComingSoon() {
        updateState {
            $0.showingComingSoon = false
        }
    }

    // MARK: - Private Methods

    private func createHousehold() async -> Bool {
        Self.logger.info("🏗️ Creating household: \(state.name)")

        guard validateForm() else {
            Self.logger.warning("⚠️ Form validation failed")
            return false
        }

        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = state.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedDescription.isEmpty ? nil : trimmedDescription

        let result: Household? = await executeTask(.save) { [weak self, dependencies] in
            let household = try await dependencies.householdService.createHousehold(
                name: trimmedName,
                description: description
            )

            await MainActor.run {
                self?.updateState {
                    $0.originalHousehold = household
                    $0.householdId = household.id
                    $0.hasUnsavedChanges = false
                    $0.viewState = .loaded
                }
            }

            return household
        }

        return result != nil
    }

    private func updateHousehold() async -> Bool {
        guard state.householdId != nil else {
            Self.logger.error("❌ Cannot update household - no ID available")
            return false
        }

        Self.logger.info("✏️ Would update household: \(state.name) - showing coming soon")

        // Show coming soon alert instead of actually updating
        updateState {
            $0.showingComingSoon = true
        }

        // Return false to prevent dismissing the view
        return false
    }

    private func performLoadHousehold(id: String) async {
        Self.logger.info("📡 Loading household: \(id)")

        updateState { $0.viewState = .loading }

        do {
            let households = try await dependencies.householdService.getHouseholds()
            guard let household = households.first(where: { $0.id == id }) else {
                throw ViewModelError.operationFailed("Household not found")
            }

            updateState { state in
                state.originalHousehold = household
                state.name = household.name
                state.description = household.description ?? ""
                state.hasUnsavedChanges = false
                state.viewState = .loaded
            }

            Self.logger.info("✅ Household loaded: \(household.name)")

        } catch {
            Self.logger.error("❌ Failed to load household: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    // MARK: - Permission Checking

    private func checkEditPermission(for _: String, userId _: String) async -> Bool {
        // Check if user is owner or admin of the household
        // For now, we'll use a simple check - in real app, this would use CASL permissions
        if state.originalHousehold != nil {
            // If we already have the household, check if user is the owner
            // In a real app, we'd check member roles here
            return true // For now, allow editing if they can view it
        }
        return true
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
