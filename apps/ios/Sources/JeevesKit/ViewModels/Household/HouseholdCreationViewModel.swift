import Foundation
import SwiftUI

// MARK: - HouseholdCreationViewModel

/// ViewModel for managing household creation during onboarding or regular flow
@Observable @MainActor
public final class HouseholdCreationViewModel: BaseReactiveViewModel<HouseholdCreationState, HouseholdCreationDependencies> {
    private static let logger = Logger(category: "HouseholdCreationViewModel")

    // MARK: - Initialization

    public required init(dependencies: HouseholdCreationDependencies) {
        super.init(dependencies: dependencies, initialState: HouseholdCreationState())
    }

    // Required by BaseReactiveViewModel
    public required init(dependencies: HouseholdCreationDependencies, initialState: HouseholdCreationState) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Public Methods

    /// Update household name
    public func updateHouseholdName(_ name: String) {
        updateState { $0.householdName = name }
        clearError()
    }

    /// Update household description
    public func updateHouseholdDescription(_ description: String) {
        updateState { $0.householdDescription = description }
        clearError()
    }

    /// Create the household
    public func createHousehold() async -> String? {
        let trimmedName = state.householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            Self.logger.warning("Attempted to create household with empty name")
            return nil
        }

        return await executeTask(.create) { @MainActor in
            let trimmedDescription = self.state.householdDescription.trimmingCharacters(in: .whitespacesAndNewlines)

            let household = try await self.dependencies.householdService.createHousehold(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            )

            Self.logger.info("Successfully created household: \(household.id)")

            // Update state with created household
            self.updateState { $0.createdHousehold = household }

            return household.id
        }
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
        !state.householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if loading
    public var isLoading: Bool {
        loadingStates.isLoading(.create) || loadingStates.isLoading(.initial)
    }
}

// MARK: - State

/// State for household creation
public struct HouseholdCreationState: Equatable, Sendable {
    public var householdName: String = ""
    public var householdDescription: String = ""
    public var createdHousehold: Household?
}

// MARK: - Dependencies

/// Dependencies for HouseholdCreationViewModel
public struct HouseholdCreationDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol
    public let authService: AuthServiceProtocol

    public init(
        householdService: HouseholdServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.householdService = householdService
        self.authService = authService
    }
}
