import Foundation
import SwiftUI

// MARK: - UserInfoViewModel

/// ViewModel for managing user information collection during onboarding
@Observable @MainActor
public final class UserInfoViewModel: BaseReactiveViewModel<UserInfoState, UserInfoDependencies> {
    private static let logger = Logger(category: "UserInfoViewModel")

    // MARK: - Watched Data

    /// Watched current user data that updates reactively
    public let currentUser: WatchedResult<User>

    // MARK: - Initialization

    public init(dependencies: UserInfoDependencies, currentUser: User?) {
        // Start watching current user immediately
        self.currentUser = dependencies.userService.watchCurrentUser()

        // Use provided currentUser or watched value for initial state
        let user = currentUser ?? self.currentUser.value
        let initialState = UserInfoState(
            firstName: user?.firstName ?? "",
            lastName: user?.lastName ?? "",
        )
        super.init(dependencies: dependencies, initialState: initialState)

        // Register watch for automatic cleanup
        registerWatch(self.currentUser)

        // Update state when watched user changes
        Task { @MainActor in
            await self.observeCurrentUser()
        }
    }

    // Required by BaseReactiveViewModel
    public required init(dependencies: UserInfoDependencies) {
        currentUser = dependencies.userService.watchCurrentUser()
        super.init(dependencies: dependencies, initialState: UserInfoState())

        // Register watch for automatic cleanup
        registerWatch(currentUser)

        // Update state when watched user changes
        Task { @MainActor in
            await self.observeCurrentUser()
        }
    }

    // Required by BaseReactiveViewModel
    public required init(dependencies: UserInfoDependencies, initialState: UserInfoState) {
        currentUser = dependencies.userService.watchCurrentUser()
        super.init(dependencies: dependencies, initialState: initialState)

        // Register watch for automatic cleanup
        registerWatch(currentUser)

        // Update state when watched user changes
        Task { @MainActor in
            await self.observeCurrentUser()
        }
    }

    // MARK: - Public Methods

    /// Update first name
    public func updateFirstName(_ name: String) {
        updateState { $0.firstName = name }
        clearError()
    }

    /// Update last name
    public func updateLastName(_ name: String) {
        updateState { $0.lastName = name }
        clearError()
    }

    /// Handle continue action
    public func handleContinue() async -> Bool {
        guard isFormValid else {
            Self.logger.warning("Form validation failed")
            return false
        }

        return await executeTask(.save) { @MainActor in
            let trimmedFirstName = self.state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLastName = self.state.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Get the current user to update from watched data
            guard let currentUser = self.currentUser.value else {
                Self.logger.error("No current user found to update")
                throw ServiceError.notAuthenticated
            }

            // Create updated user with new name values (optimistic update)
            let updatedUser = User(
                id: currentUser.id,
                authUserId: currentUser.authUserId,
                email: currentUser.email,
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                displayName: "\(trimmedFirstName) \(trimmedLastName)",
                avatarUrl: currentUser.avatarUrl,
                phone: currentUser.phone,
                birthDate: currentUser.birthDate,
                managedBy: currentUser.managedBy,
                relationshipToManager: currentUser.relationshipToManager,
                primaryHouseholdId: currentUser.primaryHouseholdId,
                preferences: currentUser.preferences,
                isAi: currentUser.isAi,
                createdAt: currentUser.createdAt,
                updatedAt: DateUtilities.graphQLStringFromDate(Date()),
            )

            // Perform the update
            do {
                let returnedUser = try await self.dependencies.userService.updateUser(updatedUser)
                Self.logger.info("✅ User info updated successfully: \(returnedUser.name ?? "Unknown")")

                // Note: The parent view (OnboardingContainerView) should handle updating AppState
                // after this completes. We just return success here.
                return true
            } catch {
                Self.logger.error("❌ Failed to update user info: \(error)")
                throw error
            }
        } ?? false
    }

    /// Sign out the user
    public func signOut() async {
        await executeTask(.initial) { @MainActor in
            try await self.dependencies.authService.signOut()
        }
    }

    // MARK: - Computed Properties

    /// Check if form is valid
    public var isFormValid: Bool {
        !state.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !state.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if either loading state is active
    public var isLoading: Bool {
        loadingStates.isLoading(.save) || loadingStates.isLoading(.initial) || currentUser.isLoading
    }

    // MARK: - Private Methods

    /// Observe changes to the current user
    private func observeCurrentUser() async {
        // This method would normally use Combine or async sequences
        // For now, we'll rely on SwiftUI's @Observable to handle updates
        // The WatchedResult is @Observable, so changes will trigger UI updates
    }

    // MARK: - WatchedResult Helpers Override

    override public var isWatchedDataLoading: Bool {
        currentUser.isLoading
    }

    override public var watchedDataError: Error? {
        currentUser.error
    }

    override public func retryFailedWatches() async {
        if currentUser.error != nil {
            await currentUser.retry()
        }
    }
}

// MARK: - State

/// State for user info collection
public struct UserInfoState: Equatable, Sendable {
    public var firstName: String = ""
    public var lastName: String = ""
}

// MARK: - Dependencies

/// Dependencies for UserInfoViewModel
public struct UserInfoDependencies: Sendable {
    public let userService: UserServiceProtocol
    public let authService: AuthServiceProtocol

    public init(
        userService: UserServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.userService = userService
        self.authService = authService
    }
}
