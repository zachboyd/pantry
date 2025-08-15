import Foundation
import Observation

// MARK: - HouseholdJoinViewModel

/// ViewModel for joining an existing household via invite code
@Observable @MainActor
public final class HouseholdJoinViewModel: BaseReactiveViewModel<HouseholdJoinState, HouseholdJoinDependencies> {
    private static let logger = Logger.ui

    // MARK: - Computed Properties

    public var inviteCode: String {
        get { state.inviteCode }
        set {
            updateState { $0.inviteCode = newValue }
            validateInviteCode()
        }
    }

    public var isJoining: Bool {
        state.isJoining
    }

    public var joinError: Error? {
        state.joinError
    }

    public var validationError: String? {
        state.validationError
    }

    public var isFormValid: Bool {
        state.inviteCode.trimmed().count >= 6 && state.validationError == nil
    }

    // MARK: - Initialization

    public required init(dependencies: HouseholdJoinDependencies) {
        super.init(dependencies: dependencies, initialState: HouseholdJoinState())
        Self.logger.info("🏠 HouseholdJoinViewModel initialized")
    }

    // Required by BaseReactiveViewModel
    public required init(dependencies: HouseholdJoinDependencies, initialState: HouseholdJoinState) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Public Methods

    /// Join household with the provided invite code
    /// Returns the household ID if successful
    @MainActor
    public func joinHousehold() async -> UUID? {
        guard isFormValid else {
            Self.logger.warning("⚠️ Cannot join household - form validation failed")
            return nil
        }

        Self.logger.info("🏠 Joining household with invite code")

        return await executeTask(.create) { @MainActor in
            let trimmedCode = self.state.inviteCode.trimmed()
            let household = try await self.dependencies.householdService.joinHousehold(inviteCode: trimmedCode)

            Self.logger.info("✅ Successfully joined household: \(household.name)")

            self.updateState {
                $0.inviteCode = ""
                $0.joinError = nil
            }

            return household.id
        }
    }

    /// Validate the invite code
    public func validateInviteCode() {
        updateState { $0.validationError = nil }

        let trimmedCode = state.inviteCode.trimmed()

        if !trimmedCode.isEmpty, trimmedCode.count < 6 {
            updateState { $0.validationError = L("household.invite_code.minimum_length") }
        }
    }

    /// Clear any join error
    override public func clearError() {
        updateState {
            $0.joinError = nil
            $0.validationError = nil
        }
        super.clearError()
    }
}

// MARK: - State

/// State for household joining
public struct HouseholdJoinState: Equatable, Sendable {
    public var inviteCode: String = ""
    public var isJoining: Bool = false
    public var joinError: Error?
    public var validationError: String?

    public static func == (lhs: HouseholdJoinState, rhs: HouseholdJoinState) -> Bool {
        lhs.inviteCode == rhs.inviteCode &&
            lhs.isJoining == rhs.isJoining &&
            lhs.validationError == rhs.validationError
        // Note: Error is not Equatable, so we exclude joinError from equality
    }
}

// MARK: - Dependencies

/// Dependencies required for HouseholdJoinViewModel
public struct HouseholdJoinDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol

    public init(householdService: HouseholdServiceProtocol) {
        self.householdService = householdService
    }
}
