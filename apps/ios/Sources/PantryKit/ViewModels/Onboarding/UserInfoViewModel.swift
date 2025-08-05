import Foundation
import SwiftUI

// MARK: - UserInfoViewModel

/// ViewModel for managing user information collection during onboarding
@Observable @MainActor
public final class UserInfoViewModel: BaseReactiveViewModel<UserInfoState, UserInfoDependencies> {
    private static let logger = Logger(category: "UserInfoViewModel")
    
    // MARK: - Initialization
    
    public init(dependencies: UserInfoDependencies, currentUser: User?) {
        let initialState = UserInfoState(
            firstName: currentUser?.firstName ?? "",
            lastName: currentUser?.lastName ?? ""
        )
        super.init(dependencies: dependencies, initialState: initialState)
    }
    
    // Required by BaseReactiveViewModel
    public required init(dependencies: UserInfoDependencies) {
        super.init(dependencies: dependencies, initialState: UserInfoState())
    }
    
    // Required by BaseReactiveViewModel
    public required init(dependencies: UserInfoDependencies, initialState: UserInfoState) {
        super.init(dependencies: dependencies, initialState: initialState)
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
            
            // Get the current user to update
            guard let currentUser = try await self.dependencies.userService.getCurrentUser() else {
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
                createdAt: currentUser.createdAt,
                updatedAt: DateUtilities.graphQLStringFromDate(Date())
            )
            
            // Perform the update
            do {
                let returnedUser = try await self.dependencies.userService.updateUser(updatedUser)
                Self.logger.info("✅ User info updated successfully: \(returnedUser.name ?? "Unknown")")
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
        loadingStates.isLoading(.save) || loadingStates.isLoading(.initial)
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