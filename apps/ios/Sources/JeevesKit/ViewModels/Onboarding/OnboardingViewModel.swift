import Foundation
import Observation

// MARK: - OnboardingStep

/// Represents a step in the onboarding flow
public struct OnboardingStep: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let isRequired: Bool
    public let canSkip: Bool
    public let action: OnboardingAction

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        isRequired: Bool = true,
        canSkip: Bool = false,
        action: OnboardingAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isRequired = isRequired
        self.canSkip = canSkip
        self.action = action
    }
}

/// Actions that can be performed during onboarding
public enum OnboardingAction: Sendable {
    case createHousehold
    case joinHousehold
    case skipHousehold
    case setupProfile
    case enableNotifications
    case finish
}

// MARK: - OnboardingViewModel

/// ViewModel for managing the onboarding flow
@Observable @MainActor
public final class OnboardingViewModel: BaseReactiveViewModel<OnboardingViewModel.State, OnboardingDependencies> {
    private static let logger = Logger.ui

    // MARK: - State

    public struct State: Sendable {
        var currentStepIndex = 0
        var steps: [OnboardingStep] = []
        var isCompleted = false
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?

        // Form data
        var householdName = ""
        var householdDescription = ""
        var inviteCode = ""
        var userName = ""
        var notificationsEnabled = false

        // Progress tracking
        var completedSteps: Set<String> = []
    }

    // MARK: - Computed Properties

    public var currentStep: OnboardingStep? {
        guard state.currentStepIndex < state.steps.count else { return nil }
        return state.steps[state.currentStepIndex]
    }

    public var currentStepIndex: Int {
        state.currentStepIndex
    }

    public var totalSteps: Int {
        state.steps.count
    }

    public var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(state.currentStepIndex) / Double(totalSteps)
    }

    public var canGoNext: Bool {
        guard let step = currentStep else { return false }

        // Check if step is completed or can be skipped
        if state.completedSteps.contains(step.id) || step.canSkip {
            return true
        }

        // Check step-specific requirements
        switch step.action {
        case .createHousehold:
            return !state.householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .joinHousehold:
            return !state.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .setupProfile:
            return !state.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .skipHousehold, .enableNotifications, .finish:
            return true
        }
    }

    public var canGoPrevious: Bool {
        state.currentStepIndex > 0
    }

    public var isCompleted: Bool {
        state.isCompleted
    }

    public var showLoadingIndicator: Bool {
        loadingStates.isAnyLoading
    }

    // Form properties
    public var householdName: String {
        get { state.householdName }
        set { updateState { $0.householdName = newValue } }
    }

    public var householdDescription: String {
        get { state.householdDescription }
        set { updateState { $0.householdDescription = newValue } }
    }

    public var inviteCode: String {
        get { state.inviteCode }
        set { updateState { $0.inviteCode = newValue } }
    }

    public var userName: String {
        get { state.userName }
        set { updateState { $0.userName = newValue } }
    }

    public var notificationsEnabled: Bool {
        get { state.notificationsEnabled }
        set { updateState { $0.notificationsEnabled = newValue } }
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    public var showingError: Bool {
        state.showingError
    }

    // MARK: - Initialization

    public required init(dependencies: OnboardingDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)

        setupOnboardingSteps()
        Self.logger.info("🚀 OnboardingViewModel initialized with \(state.steps.count) steps")
    }

    public required init(dependencies: OnboardingDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)

        if initialState.steps.isEmpty {
            setupOnboardingSteps()
        }
    }

    // MARK: - Public Methods

    /// Move to the next step
    public func goToNextStep() {
        guard canGoNext else {
            Self.logger.warning("⚠️ Cannot proceed to next step - requirements not met")
            return
        }

        if let step = currentStep {
            executeTask(.update) { [weak self] in
                guard let self else { return }
                await processCurrentStep(step)

                await MainActor.run {
                    if self.state.currentStepIndex < self.state.steps.count - 1 {
                        self.updateState { $0.currentStepIndex += 1 }
                        Self.logger.info("📍 Advanced to step \(self.state.currentStepIndex + 1)")
                    } else {
                        self.completeOnboarding()
                    }
                }
            }
        }
    }

    /// Move to the previous step
    public func goToPreviousStep() {
        guard canGoPrevious else { return }

        updateState { $0.currentStepIndex -= 1 }
        Self.logger.info("📍 Went back to step \(state.currentStepIndex + 1)")
    }

    /// Skip the current step (if allowed)
    public func skipCurrentStep() {
        guard let step = currentStep, step.canSkip else {
            Self.logger.warning("⚠️ Current step cannot be skipped")
            return
        }

        markStepCompleted(step.id)
        goToNextStep()
        Self.logger.info("⏭️ Skipped step: \(step.title)")
    }

    /// Restart the onboarding flow
    public func restart() {
        updateState {
            $0.currentStepIndex = 0
            $0.isCompleted = false
            $0.completedSteps.removeAll()
            $0.viewState = .idle
            $0.showingError = false
            $0.errorMessage = nil

            // Clear form data
            $0.householdName = ""
            $0.householdDescription = ""
            $0.inviteCode = ""
            $0.userName = ""
            $0.notificationsEnabled = false
        }

        Self.logger.info("🔄 Onboarding restarted")
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

    private func setupOnboardingSteps() {
        let steps: [OnboardingStep] = [
            OnboardingStep(
                id: "welcome",
                title: L("onboarding.welcome.title"),
                subtitle: L("onboarding.welcome.subtitle"),
                isRequired: true,
                canSkip: false,
                action: .setupProfile,
            ),
            OnboardingStep(
                id: "household_choice",
                title: L("onboarding.household.title"),
                subtitle: L("onboarding.household.subtitle"),
                isRequired: true,
                canSkip: false,
                action: .createHousehold,
            ),
            OnboardingStep(
                id: "notifications",
                title: L("onboarding.notifications.title"),
                subtitle: L("onboarding.notifications.subtitle"),
                isRequired: false,
                canSkip: true,
                action: .enableNotifications,
            ),
            OnboardingStep(
                id: "finish",
                title: L("onboarding.complete.title"),
                subtitle: L("onboarding.complete.subtitle"),
                isRequired: true,
                canSkip: false,
                action: .finish,
            ),
        ]

        updateState { $0.steps = steps }
    }

    private func processCurrentStep(_ step: OnboardingStep) async {
        Self.logger.info("🔄 Processing step: \(step.title)")

        do {
            switch step.action {
            case .setupProfile:
                try await setupUserProfile()

            case .createHousehold:
                try await createHousehold()

            case .joinHousehold:
                try await joinHousehold()

            case .skipHousehold:
                Self.logger.info("⏭️ Skipping household setup")

            case .enableNotifications:
                await enableNotifications()

            case .finish:
                Self.logger.info("🎉 Onboarding completion step")
            }

            await MainActor.run {
                self.markStepCompleted(step.id)
            }

        } catch {
            Self.logger.error("❌ Step processing failed: \(error)")
            await MainActor.run {
                self.handleError(error)
            }
        }
    }

    private func setupUserProfile() async throws {
        guard !state.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ViewModelError.validationFailed([ValidationError.required("name")])
        }

        Self.logger.info("👤 Setting up user profile")

        // Update user profile through user service
        // This is a placeholder - implement based on your user service
        Self.logger.info("✅ User profile setup completed")
    }

    private func createHousehold() async throws {
        let trimmedName = state.householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ViewModelError.validationFailed([ValidationError.required("household name")])
        }

        Self.logger.info("🏠 Creating household: \(trimmedName)")

        let trimmedDescription = state.householdDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedDescription.isEmpty ? nil : trimmedDescription

        // Create household through household service
        let household = try await dependencies.householdService.createHousehold(
            name: trimmedName,
            description: description,
        )

        Self.logger.info("✅ Household created successfully: \(household.name)")
    }

    private func joinHousehold() async throws {
        let trimmedCode = state.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw ViewModelError.validationFailed([ValidationError.required("invite code")])
        }

        Self.logger.info("🤝 Joining household with code: \(trimmedCode)")

        // Join household through household service
        _ = try await dependencies.householdService.joinHousehold(inviteCode: trimmedCode)

        Self.logger.info("✅ Successfully joined household")
    }

    private func enableNotifications() async {
        Self.logger.info("🔔 Processing notification permissions")

        if state.notificationsEnabled {
            // Request notification permissions
            // This would typically involve UNUserNotificationCenter
            Self.logger.info("✅ Notifications enabled")
        } else {
            Self.logger.info("⏭️ Notifications skipped")
        }
    }

    private func markStepCompleted(_ stepId: String) {
        updateState {
            $0.completedSteps.insert(stepId)
        }
        Self.logger.debug("✅ Step completed: \(stepId)")
    }

    private func completeOnboarding() {
        updateState {
            $0.isCompleted = true
            $0.viewState = .loaded
        }
        Self.logger.info("🎉 Onboarding completed successfully")
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ OnboardingViewModel appeared")
        await super.onAppear()
    }

    override public func onDisappear() async {
        Self.logger.debug("👁️ OnboardingViewModel disappeared")
        await super.onDisappear()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 OnboardingViewModel refresh")
        // Onboarding typically shouldn't refresh, but we can reset to current step
        await super.refresh()
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
