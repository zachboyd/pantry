import Foundation
import SwiftUI

// MARK: - OnboardingContainerViewModel

/// ViewModel for managing the onboarding container flow
@Observable @MainActor
public final class OnboardingContainerViewModel: BaseReactiveViewModel<OnboardingContainerState, OnboardingDependencies> {
    private static let logger = Logger(category: "OnboardingContainerViewModel")

    // MARK: - Initialization

    public required init(dependencies: OnboardingDependencies) {
        super.init(dependencies: dependencies, initialState: OnboardingContainerState())
    }

    // Required by BaseReactiveViewModel
    public required init(dependencies: OnboardingDependencies, initialState: OnboardingContainerState) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        await determineOnboardingFlow()
    }

    // MARK: - Public Methods

    /// Determine which onboarding steps are needed based on user state
    public func determineOnboardingFlow() async {
        await executeTask(.initial) { @MainActor in
            self.updateState { $0.currentStep = .loading }

            do {
                // Get current user data
                if let currentUser = try await self.dependencies.userService.getCurrentUser() {
                    self.updateState { $0.currentUser = currentUser }

                    // Check if user needs to fill in name info
                    let needsUserInfo = currentUser.firstName.isEmpty || currentUser.lastName.isEmpty

                    // Note: Households are already hydrated in AppState during app initialization
                    // We check the user's household status through the service
                    let userHouseholds = try await self.dependencies.householdService.getUserHouseholds()
                    self.updateState { $0.userHouseholds = userHouseholds }

                    // Determine starting step
                    if needsUserInfo {
                        self.updateState { $0.currentStep = .userInfo }
                    } else if userHouseholds.isEmpty {
                        self.updateState { $0.currentStep = .householdCreation }
                    } else {
                        // User has all required info and is in a household
                        self.updateState { $0.currentStep = .complete }
                    }

                    Self.logger.info("Onboarding flow determined: \(self.state.currentStep)")
                } else {
                    // No current user, start with user info
                    self.updateState { $0.currentStep = .userInfo }
                }

            } catch {
                Self.logger.error("Failed to determine onboarding flow: \(error)")
                // If we can't get user data, start with user info
                self.updateState { $0.currentStep = .userInfo }
            }
        }
    }

    /// Move to the next appropriate step in the flow
    public func moveToNextStep() {
        withAnimation(DesignTokens.Animation.Component.sheetPresentation) {
            switch state.currentStep {
            case .loading:
                // Should not happen
                break

            case .userInfo:
                // After user info, check if they need to create a household
                if state.userHouseholds.isEmpty {
                    updateState { $0.currentStep = .householdCreation }
                } else {
                    updateState { $0.currentStep = .complete }
                }

            case .householdCreation:
                // This is the last step
                updateState { $0.currentStep = .complete }

            case .complete:
                // Already complete
                break
            }

            Self.logger.info("Moved to next step: \(state.currentStep)")
        }
    }

    /// Handle completion of user info step
    public func handleUserInfoComplete() {
        // Refresh user data after update to ensure state is current
        Task {
            await executeTask(.refresh) { @MainActor in
                if let updatedUser = try await self.dependencies.userService.getCurrentUser() {
                    self.updateState { $0.currentUser = updatedUser }
                    Self.logger.info("✅ Refreshed user data after update: \(updatedUser.name ?? "Unknown")")
                }
            }
        }
        moveToNextStep()
    }

    /// Handle completion of household creation
    public func handleHouseholdCreated(householdId: UUID) {
        updateState {
            $0.selectedHouseholdId = householdId
            $0.currentStep = .complete
        }
    }

    /// Get the household ID for completing onboarding
    public func getCompletionHouseholdId() -> UUID? {
        if let selectedId = state.selectedHouseholdId {
            return selectedId
        }
        return state.userHouseholds.first?.id
    }

    /// Sign out the user
    public func signOut() async throws {
        Self.logger.info("🚪 Signing out from onboarding")
        try await dependencies.authService.signOut()
    }
}

// MARK: - State

/// Onboarding flow steps for view model
public enum OnboardingContainerStep: Equatable, Sendable {
    case loading
    case userInfo
    case householdCreation
    case complete
}

/// State for onboarding container
public struct OnboardingContainerState: Equatable, Sendable {
    public var currentStep: OnboardingContainerStep = .loading
    public var currentUser: User?
    public var userHouseholds: [Household] = []
    public var selectedHouseholdId: UUID?

    public var isLoading: Bool {
        currentStep == .loading
    }

    public var shouldShowCompleteView: Bool {
        currentStep == .complete && selectedHouseholdId == nil
    }
}
