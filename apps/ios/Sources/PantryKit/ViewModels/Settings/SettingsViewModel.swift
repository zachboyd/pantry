import Foundation
import Observation

// MARK: - SettingsViewModel

/// ViewModel for managing user settings and profile
@Observable @MainActor
public final class SettingsViewModel: BaseReactiveViewModel<SettingsViewModel.State, SettingsDependencies> {
    private static let logger = Logger.ui

    // MARK: - State

    public struct State: Sendable {
        var currentUser: User?
        var userHouseholds: [Household] = []
        var selectedHouseholdId: String?
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?

        // Profile editing
        var isEditingProfile = false
        var editedName = ""
        var editedEmail = ""
        var nameError: String?
        var emailError: String?

        // Settings
        var notificationsEnabled = true
        var pushNotificationsEnabled = true
        var emailNotificationsEnabled = true
        var expirationReminders = true
        var lowStockAlerts = true
        var householdUpdates = true

        // UI state
        var showingSignOutConfirmation = false
        var showingHouseholdSwitcher = false
        var showingDeleteAccountConfirmation = false
    }

    // MARK: - Computed Properties

    public var currentUser: User? {
        state.currentUser
    }

    public var userHouseholds: [Household] {
        state.userHouseholds
    }

    public var selectedHouseholdId: String? {
        state.selectedHouseholdId
    }

    public var selectedHousehold: Household? {
        guard let selectedId = state.selectedHouseholdId else { return nil }
        return state.userHouseholds.first { $0.id == selectedId }
    }

    public var userDisplayName: String {
        state.currentUser?.name ?? state.currentUser?.email ?? "Unknown User"
    }

    public var userEmail: String {
        state.currentUser?.email ?? ""
    }

    public var userInitials: String {
        guard let user = state.currentUser else { return "U" }

        if let name = user.name, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.map(String.init)
            return initials.prefix(2).joined().uppercased()
        } else if let email = user.email, !email.isEmpty {
            return String(email.prefix(2)).uppercased()
        } else {
            return "U"
        }
    }

    // Profile editing
    public var isEditingProfile: Bool {
        get { state.isEditingProfile }
        set { updateState { $0.isEditingProfile = newValue } }
    }

    public var editedName: String {
        get { state.editedName }
        set {
            updateState { $0.editedName = newValue }
            validateName()
        }
    }

    public var editedEmail: String {
        get { state.editedEmail }
        set {
            updateState { $0.editedEmail = newValue }
            validateEmail()
        }
    }

    public var nameError: String? {
        state.nameError
    }

    public var emailError: String? {
        state.emailError
    }

    public var canSaveProfile: Bool {
        !state.editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !state.editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            state.nameError == nil &&
            state.emailError == nil &&
            (state.editedName != (state.currentUser?.name ?? "") ||
                state.editedEmail != (state.currentUser?.email ?? ""))
    }

    // Notification settings
    public var notificationsEnabled: Bool {
        get { state.notificationsEnabled }
        set {
            updateState { $0.notificationsEnabled = newValue }
            saveNotificationSettings()
        }
    }

    public var pushNotificationsEnabled: Bool {
        get { state.pushNotificationsEnabled }
        set {
            updateState { $0.pushNotificationsEnabled = newValue }
            saveNotificationSettings()
        }
    }

    public var emailNotificationsEnabled: Bool {
        get { state.emailNotificationsEnabled }
        set {
            updateState { $0.emailNotificationsEnabled = newValue }
            saveNotificationSettings()
        }
    }

    public var expirationReminders: Bool {
        get { state.expirationReminders }
        set {
            updateState { $0.expirationReminders = newValue }
            saveNotificationSettings()
        }
    }

    public var lowStockAlerts: Bool {
        get { state.lowStockAlerts }
        set {
            updateState { $0.lowStockAlerts = newValue }
            saveNotificationSettings()
        }
    }

    public var householdUpdates: Bool {
        get { state.householdUpdates }
        set {
            updateState { $0.householdUpdates = newValue }
            saveNotificationSettings()
        }
    }

    // UI state
    public var showingSignOutConfirmation: Bool {
        get { state.showingSignOutConfirmation }
        set { updateState { $0.showingSignOutConfirmation = newValue } }
    }

    public var showingHouseholdSwitcher: Bool {
        get { state.showingHouseholdSwitcher }
        set { updateState { $0.showingHouseholdSwitcher = newValue } }
    }

    public var showingDeleteAccountConfirmation: Bool {
        get { state.showingDeleteAccountConfirmation }
        set { updateState { $0.showingDeleteAccountConfirmation = newValue } }
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

    public var isAuthenticated: Bool {
        dependencies.authService.isAuthenticated
    }

    // MARK: - Initialization

    public required init(dependencies: SettingsDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("⚙️ SettingsViewModel initialized")

        loadNotificationSettings()
        loadSelectedHousehold()
    }

    public required init(dependencies: SettingsDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
        loadNotificationSettings()
        loadSelectedHousehold()
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ SettingsViewModel appeared")
        await super.onAppear()

        await loadUserProfile()
        await loadUserHouseholds()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 SettingsViewModel refresh")
        await loadUserProfile()
        await loadUserHouseholds()
        await super.refresh()
    }

    // MARK: - Public Methods

    /// Load user profile information
    public func loadUserProfile() async {
        await executeTask(.load) { [weak self] in
            guard let self = self else { return }
            await self.performLoadUserProfile()
        }
    }

    /// Load user's households
    public func loadUserHouseholds() async {
        await executeTask(.load) { [weak self] in
            guard let self = self else { return }
            await self.performLoadUserHouseholds()
        }
    }

    /// Start editing profile
    public func startEditingProfile() {
        guard let user = state.currentUser else { return }

        updateState {
            $0.isEditingProfile = true
            $0.editedName = user.name ?? ""
            $0.editedEmail = user.email ?? ""
            $0.nameError = nil
            $0.emailError = nil
        }

        Self.logger.info("✏️ Started editing profile")
    }

    /// Cancel profile editing
    public func cancelEditingProfile() {
        updateState {
            $0.isEditingProfile = false
            $0.editedName = ""
            $0.editedEmail = ""
            $0.nameError = nil
            $0.emailError = nil
        }

        Self.logger.info("❌ Cancelled profile editing")
    }

    /// Save profile changes
    public func saveProfile() async -> Bool {
        guard canSaveProfile else {
            Self.logger.warning("⚠️ Cannot save profile - validation failed")
            return false
        }

        Self.logger.info("💾 Saving profile changes")

        let result: User? = await executeTask(.save) { [weak self] in
            guard let self = self else { throw ViewModelError.unknown("Self reference lost") }

            // Create user preferences object with updated info
            let preferences = await MainActor.run {
                UserPreferences(
                    name: self.state.editedName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: self.state.editedEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    notificationsEnabled: self.state.notificationsEnabled,
                    pushNotificationsEnabled: self.state.pushNotificationsEnabled,
                    emailNotificationsEnabled: self.state.emailNotificationsEnabled
                )
            }

            let updatedUser = try await self.dependencies.userPreferencesService.updateUserPreferences(preferences)

            await MainActor.run {
                self.updateState {
                    $0.currentUser = updatedUser
                    $0.isEditingProfile = false
                    $0.editedName = ""
                    $0.editedEmail = ""
                }
            }

            return updatedUser
        }

        return result != nil
    }

    /// Switch to a different household
    public func switchHousehold(to household: Household) {
        Self.logger.info("🏠 Switching to household: \(household.name)")

        updateState {
            $0.selectedHouseholdId = household.id
            $0.showingHouseholdSwitcher = false
        }

        // Persist the selection
        UserDefaults.standard.set(household.id, forKey: "selectedHouseholdId")

        // Notify other parts of the app about the household change
        NotificationCenter.default.post(
            name: NSNotification.Name("HouseholdDidChange"),
            object: nil,
            userInfo: ["householdId": household.id]
        )
    }

    /// Show sign out confirmation
    public func showSignOutConfirmation() {
        updateState { $0.showingSignOutConfirmation = true }
    }

    /// Hide sign out confirmation
    public func hideSignOutConfirmation() {
        updateState { $0.showingSignOutConfirmation = false }
    }

    /// Sign out the current user
    public func signOut() async -> Bool {
        Self.logger.info("🚪 Signing out user")

        let result: Void? = await executeTask(.update) { [weak self] in
            guard let self = self else { return }
            try await self.dependencies.authService.signOut()

            await MainActor.run {
                // Clear user data
                self.updateState {
                    $0.currentUser = nil
                    $0.userHouseholds = []
                    $0.selectedHouseholdId = nil
                    $0.showingSignOutConfirmation = false
                }

                // Clear persisted household selection
                UserDefaults.standard.removeObject(forKey: "selectedHouseholdId")
            }
        }

        return result != nil
    }

    /// Show household switcher
    public func showHouseholdSwitcher() {
        updateState { $0.showingHouseholdSwitcher = true }
    }

    /// Hide household switcher
    public func hideHouseholdSwitcher() {
        updateState { $0.showingHouseholdSwitcher = false }
    }

    /// Show delete account confirmation
    public func showDeleteAccountConfirmation() {
        updateState { $0.showingDeleteAccountConfirmation = true }
    }

    /// Hide delete account confirmation
    public func hideDeleteAccountConfirmation() {
        updateState { $0.showingDeleteAccountConfirmation = false }
    }

    /// Delete user account (placeholder)
    public func deleteAccount() async -> Bool {
        Self.logger.warning("🗑️ Delete account requested - not implemented")

        // This would be a serious operation requiring additional confirmation
        // For now, just show an error
        updateState {
            $0.showingError = true
            $0.errorMessage = L("settings.delete_account.not_implemented")
            $0.showingDeleteAccountConfirmation = false
        }

        return false
    }

    /// Validate name field
    public func validateName() {
        updateState { $0.nameError = nil }

        let trimmedName = state.editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            updateState { $0.nameError = "Name is required" }
            return
        }

        if trimmedName.count < 2 {
            updateState { $0.nameError = "Name must be at least 2 characters" }
        }
    }

    /// Validate email field
    public func validateEmail() {
        updateState { $0.emailError = nil }

        let trimmedEmail = state.editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            updateState { $0.emailError = "Email is required" }
            return
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: trimmedEmail) {
            updateState { $0.emailError = "Please enter a valid email address" }
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

    private func performLoadUserProfile() async {
        Self.logger.info("📡 Loading user profile")

        updateState { $0.viewState = .loading }

        do {
            let user = try await dependencies.userService.getCurrentUser()

            updateState { state in
                state.currentUser = user
                state.viewState = user == nil ? .empty : .loaded
            }

            Self.logger.info("✅ User profile loaded: \(user?.name ?? user?.email ?? "Unknown")")

        } catch {
            Self.logger.error("❌ Failed to load user profile: \(error)")
            updateState { state in
                state.viewState = .error(ViewModelError.operationFailed(error.localizedDescription))
            }
            handleError(error)
        }
    }

    private func performLoadUserHouseholds() async {
        Self.logger.info("📡 Loading user households")

        do {
            let households = try await dependencies.householdService.getUserHouseholds()

            updateState { state in
                state.userHouseholds = households

                // Validate selected household
                if let selectedId = state.selectedHouseholdId,
                   !households.contains(where: { $0.id == selectedId })
                {
                    // Selected household no longer exists, clear selection
                    state.selectedHouseholdId = nil
                    UserDefaults.standard.removeObject(forKey: "selectedHouseholdId")
                }
            }

            Self.logger.info("✅ Loaded \(households.count) households")

        } catch {
            Self.logger.error("❌ Failed to load user households: \(error)")
            // Don't show error for background household loading
        }
    }

    private func loadSelectedHousehold() {
        let selectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId")
        updateState { $0.selectedHouseholdId = selectedId }
    }

    private func loadNotificationSettings() {
        let defaults = UserDefaults.standard

        updateState {
            $0.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
            $0.pushNotificationsEnabled = defaults.bool(forKey: "pushNotificationsEnabled")
            $0.emailNotificationsEnabled = defaults.bool(forKey: "emailNotificationsEnabled")
            $0.expirationReminders = defaults.bool(forKey: "expirationReminders")
            $0.lowStockAlerts = defaults.bool(forKey: "lowStockAlerts")
            $0.householdUpdates = defaults.bool(forKey: "householdUpdates")
        }

        // Set defaults if not previously set
        if !defaults.bool(forKey: "hasSetNotificationDefaults") {
            updateState {
                $0.notificationsEnabled = true
                $0.pushNotificationsEnabled = true
                $0.emailNotificationsEnabled = true
                $0.expirationReminders = true
                $0.lowStockAlerts = true
                $0.householdUpdates = true
            }

            saveNotificationSettings()
            defaults.set(true, forKey: "hasSetNotificationDefaults")
        }
    }

    private func saveNotificationSettings() {
        let defaults = UserDefaults.standard

        defaults.set(state.notificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(state.pushNotificationsEnabled, forKey: "pushNotificationsEnabled")
        defaults.set(state.emailNotificationsEnabled, forKey: "emailNotificationsEnabled")
        defaults.set(state.expirationReminders, forKey: "expirationReminders")
        defaults.set(state.lowStockAlerts, forKey: "lowStockAlerts")
        defaults.set(state.householdUpdates, forKey: "householdUpdates")

        Self.logger.debug("💾 Notification settings saved")

        // This would also sync with the server
        Task {
            await syncNotificationSettingsWithServer()
        }
    }

    private func syncNotificationSettingsWithServer() async {
        // This would sync notification preferences with the server
        // For now, just log
        Self.logger.debug("🔄 Syncing notification settings with server")
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

// MARK: - Supporting Types

// UserPreferences is now defined in ServiceProtocols.swift
