import Foundation
import Observation

// MARK: - OnboardingCoordinator

/// Coordinator for managing onboarding flow navigation and state
@Observable @MainActor
public final class OnboardingCoordinator {
    private static let logger = Logger.ui

    // MARK: - Published Properties

    /// Current presentation state
    public var isPresented = false

    /// Whether onboarding should be shown
    public var shouldShowOnboarding = false

    /// Current onboarding path
    public var onboardingPath: [OnboardingDestination] = []

    /// Whether user has completed onboarding
    public var hasCompletedOnboarding = false

    /// Current household choice for onboarding
    public var householdChoice: HouseholdChoice?

    // MARK: - Supporting Types

    /// Destinations in the onboarding flow
    public enum OnboardingDestination: Hashable, CaseIterable {
        case welcome
        case householdChoice
        case createHousehold
        case joinHousehold
        case notifications
        case completion

        public var title: String {
            switch self {
            case .welcome:
                "Welcome"
            case .householdChoice:
                "Household Setup"
            case .createHousehold:
                "Create Household"
            case .joinHousehold:
                "Join Household"
            case .notifications:
                "Notifications"
            case .completion:
                "Complete"
            }
        }

        public var isModal: Bool {
            switch self {
            case .notifications, .completion:
                true
            default:
                false
            }
        }
    }

    /// User's choice for household setup
    public enum HouseholdChoice: String, CaseIterable {
        case create
        case join
        case skip

        public var title: String {
            switch self {
            case .create:
                "Create New Household"
            case .join:
                "Join Existing Household"
            case .skip:
                "Skip for Now"
            }
        }

        public var subtitle: String {
            switch self {
            case .create:
                "Start fresh with your own household"
            case .join:
                "Join a household using an invite code"
            case .skip:
                "You can set this up later"
            }
        }
    }

    // MARK: - Initialization

    public init() {
        Self.logger.info("🚀 OnboardingCoordinator initialized")
        checkOnboardingStatus()
    }

    // MARK: - Public Methods

    /// Start the onboarding flow
    public func startOnboarding() {
        Self.logger.info("🚀 Starting onboarding flow")

        shouldShowOnboarding = true
        isPresented = true
        onboardingPath = [.welcome]
        householdChoice = nil
    }

    /// Navigate to a specific destination
    public func navigateTo(_ destination: OnboardingDestination) {
        Self.logger.info("📍 Navigating to: \(destination.title)")

        if destination.isModal {
            // For modal destinations, we might need special handling
            onboardingPath.append(destination)
        } else {
            onboardingPath.append(destination)
        }
    }

    /// Go back to previous step
    public func goBack() {
        guard !onboardingPath.isEmpty else { return }

        let removed = onboardingPath.removeLast()
        Self.logger.info("⬅️ Went back from: \(removed.title)")
    }

    /// Handle household choice selection
    public func selectHouseholdChoice(_ choice: HouseholdChoice) {
        Self.logger.info("🏠 Selected household choice: \(choice.title)")

        householdChoice = choice

        switch choice {
        case .create:
            navigateTo(.createHousehold)
        case .join:
            navigateTo(.joinHousehold)
        case .skip:
            navigateTo(.notifications)
        }
    }

    /// Complete household setup and move to next step
    public func completeHouseholdSetup() {
        Self.logger.info("✅ Household setup completed")
        navigateTo(.notifications)
    }

    /// Complete notifications setup
    public func completeNotificationsSetup() {
        Self.logger.info("🔔 Notifications setup completed")
        navigateTo(.completion)
    }

    /// Complete the entire onboarding flow
    public func completeOnboarding() {
        Self.logger.info("🎉 Onboarding completed")

        hasCompletedOnboarding = true
        shouldShowOnboarding = false
        isPresented = false
        onboardingPath.removeAll()
        householdChoice = nil

        // Save completion status
        saveOnboardingCompletion()
    }

    /// Skip onboarding entirely
    public func skipOnboarding() {
        Self.logger.info("⏭️ Onboarding skipped")

        hasCompletedOnboarding = true
        shouldShowOnboarding = false
        isPresented = false
        onboardingPath.removeAll()
        householdChoice = nil

        // Save completion status
        saveOnboardingCompletion()
    }

    /// Reset onboarding state (for testing or re-onboarding)
    public func resetOnboarding() {
        Self.logger.info("🔄 Resetting onboarding state")

        hasCompletedOnboarding = false
        shouldShowOnboarding = true
        isPresented = false
        onboardingPath.removeAll()
        householdChoice = nil

        // Clear saved completion status
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    /// Check if user should see onboarding
    public func checkOnboardingStatus() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = completed
        shouldShowOnboarding = !completed

        Self.logger.info("📊 Onboarding status checked - Completed: \(completed)")
    }

    // MARK: - Private Methods

    private func saveOnboardingCompletion() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        Self.logger.debug("💾 Onboarding completion saved")
    }
}

// MARK: - Navigation Helpers

public extension OnboardingCoordinator {
    /// Whether we can go back
    var canGoBack: Bool {
        onboardingPath.count > 1
    }

    /// Current destination
    var currentDestination: OnboardingDestination? {
        onboardingPath.last
    }

    /// Progress through onboarding (0.0 to 1.0)
    var progress: Double {
        let totalSteps = OnboardingDestination.allCases.count
        let currentStep = onboardingPath.count
        return min(Double(currentStep) / Double(totalSteps), 1.0)
    }

    /// Whether we're on the final step
    var isOnFinalStep: Bool {
        currentDestination == .completion
    }
}
