/*
 AppState.swift
 JeevesKit

 Central app state implementation using DependencyContainer
 */

import Foundation
import SwiftUI

/// App lifecycle phases
public enum AppPhase: CustomStringConvertible {
    case launching
    case initializing
    case authenticating
    case unauthenticated
    case authenticated
    case hydrating
    case hydrated
    case signingOut
    case error

    public var description: String {
        switch self {
        case .launching: return "launching"
        case .initializing: return "initializing"
        case .authenticating: return "authenticating"
        case .unauthenticated: return "unauthenticated"
        case .authenticated: return "authenticated"
        case .hydrating: return "hydrating"
        case .hydrated: return "hydrated"
        case .signingOut: return "signingOut"
        case .error: return "error"
        }
    }
}

/// Central app state implementation using DependencyContainer for services
@Observable @MainActor
public final class AppState {
    private static let logger = Logger.app

    // MARK: - State Properties

    public private(set) var phase: AppPhase = .launching
    public private(set) var needsOnboarding: Bool = false
    public private(set) var currentHousehold: Household?
    public private(set) var currentUser: User?
    public private(set) var error: Error?
    public private(set) var isInitialized: Bool = false

    // MARK: - Reactive Watchers

    private var currentHouseholdWatch: WatchedResult<Household>?

    // MARK: - Services

    public let container = DependencyContainer()

    public var authService: (any AuthServiceProtocol)? {
        container.authService
    }

    public var householdService: (any HouseholdServiceProtocol)? {
        container.householdService
    }

    public var itemService: (any ItemServiceProtocol)? {
        container.itemService
    }

    public var shoppingListService: (any ShoppingListServiceProtocol)? {
        container.shoppingListService
    }

    public var notificationService: (any NotificationServiceProtocol)? {
        container.notificationService
    }

    public var userService: (any UserServiceProtocol)? {
        container.userService
    }

    public var userPreferencesService: (any UserPreferencesServiceProtocol)? {
        container.userPreferencesService
    }

    // MARK: - Initialization

    public init() {
        Self.logger.debug("🏗️ AppState initialized")
    }

    // MARK: - Lifecycle Methods

    /// Initialize the app and all services
    public func initialize() async {
        // Prevent duplicate initialization
        guard !isInitialized else {
            Self.logger.debug("App already initialized, skipping")
            return
        }

        Self.logger.info("🚀 Starting app initialization")

        do {
            phase = .initializing

            // Initialize services
            try await container.initializeServices()

            // Check authentication state
            phase = .authenticating
            Self.logger.info("🔍 Checking for authService...")
            if let authService = authService {
                Self.logger.info("✅ AuthService found, checking authentication state")
                let isAuthenticated = authService.isAuthenticated
                Self.logger.info("🔐 Authentication state: \(isAuthenticated)")

                if isAuthenticated {
                    // Move to authenticated phase, hydration will happen separately
                    phase = .authenticated
                    // Start hydration process
                    Task {
                        await startHydration()
                    }
                } else {
                    phase = .unauthenticated
                }
            } else {
                Self.logger.warning("⚠️ AuthService not found, setting phase to unauthenticated")
                phase = .unauthenticated
            }

            isInitialized = true
            Self.logger.info("✅ App initialization complete. Phase: \(String(describing: phase))")

        } catch {
            Self.logger.error("❌ App initialization failed: \(error)")
            self.error = error
            phase = .error
        }
    }

    /// Sign out the current user
    public func signOut() async {
        Self.logger.info("🚪 Starting sign out")
        phase = .signingOut

        // Always clear local state regardless of network sign out success
        defer {
            // Clear reactive watchers (they'll be cancelled when tasks are cancelled)

            // Clear user data
            currentHousehold = nil
            currentUser = nil
            needsOnboarding = false

            // Always go to unauthenticated state - user should be able to sign in again
            // even if network sign out failed
            phase = .unauthenticated
            Self.logger.info("✅ Sign out complete - user can sign in again")
        }

        do {
            // Attempt to sign out from auth service
            if let authService = authService {
                try await authService.signOut()
                Self.logger.info("✅ Network sign out successful")
            }

            // Clear all services
            await container.clearServices()

        } catch {
            Self.logger.warning("⚠️ Network sign out failed, but continuing with local sign out: \(error)")
            // Don't set error state - local sign out should still proceed
            // The defer block will ensure we go to unauthenticated state
        }
    }

    /// Retry after an error
    public func retry() async {
        Self.logger.info("🔄 Retrying after error")
        error = nil
        await initialize()
    }

    /// Handle successful authentication
    public func handleAuthenticated() async {
        Self.logger.info("🔐 Handling successful authentication")

        // Update to authenticated state
        phase = .authenticated
        Self.logger.info("✅ Successfully transitioned to authenticated state")

        // Start hydration process
        await startHydration()
    }

    /// Update the selected household
    public func selectHousehold(_ household: Household?) {
        Self.logger.info("🏠 Selecting household: \(household?.name ?? "none")")
        currentHousehold = household

        // Setup watcher for the new household to keep it reactive
        // This will automatically stop any existing watcher first
        setupHouseholdWatcher()

        // Persist selection
        if let household = household {
            Task {
                await userPreferencesService?.setLastSelectedHouseholdId(household.id)
            }
        }
    }

    /// Switch to a different household
    public func switchHousehold(to household: Household) async {
        Self.logger.info("🔄 Switching to household: \(household.name)")

        // Update current household
        selectHousehold(household)

        // Reset any tab-specific state
        // This ensures all tabs reload with the new household context
        NotificationCenter.default.post(name: .householdChanged, object: household)

        Self.logger.info("✅ Household switch complete")
    }

    /// Refresh the current user from the backend
    public func refreshCurrentUser() async {
        Self.logger.info("🔄 Refreshing current user")

        if let userService = userService {
            do {
                if let refreshedUser = try await userService.getCurrentUser() {
                    Self.logger.info("✅ User refreshed: \(refreshedUser.name ?? "Unknown")")
                    currentUser = refreshedUser
                }
            } catch {
                Self.logger.error("❌ Failed to refresh user: \(error)")
            }
        }
    }

    /// Complete onboarding with a selected household
    public func completeOnboarding(householdId: String) async {
        Self.logger.info("🎉 Completing onboarding with household: \(householdId)")

        // Get the household
        if let householdService = householdService,
           let userService = userService
        {
            do {
                // Refresh the current user to get updated name
                if let refreshedUser = try await userService.getCurrentUser() {
                    Self.logger.info("🔄 Refreshed user after onboarding: \(refreshedUser.name ?? "Unknown")")
                    currentUser = refreshedUser
                }

                let household = try await householdService.getHousehold(id: householdId)
                currentHousehold = household
                needsOnboarding = false
                phase = .hydrated

                // Persist selection
                await userPreferencesService?.setLastSelectedHouseholdId(householdId)

                Self.logger.info("✅ Onboarding completed successfully")
            } catch {
                Self.logger.error("❌ Failed to complete onboarding: \(error)")
                self.error = error
            }
        }
    }

    // MARK: - Private Methods

    /// Start the hydration process
    private func startHydration() async {
        Self.logger.info("💧 Starting hydration process")

        // Transition to hydrating phase
        phase = .hydrating

        do {
            // First, get the user ID from auth service
            guard let authService = authService,
                  let userId = authService.currentUser?.id
            else {
                Self.logger.error("❌ No authenticated user found for service initialization")
                throw AppError.authenticationFailed
            }

            // Initialize all services for the authenticated user
            Self.logger.info("🔧 Initializing all services for authenticated user: \(userId)")
            try await container.initializeForUser(userId)
            Self.logger.info("✅ All services initialized successfully")

            // Don't setup cache observers yet - wait until after hydration
            // so we have initial data to observe

            // Load user permissions
            Self.logger.info("🔐 Loading user permissions")
            await authService.loadUserPermissions()
            Self.logger.info("✅ User permissions loaded")

            // Execute the hydrate query
            try await hydrateUserData()

            // Setup reactive household watcher AFTER hydration
            // This ensures currentHousehold stays in sync with Apollo cache changes
            setupHouseholdWatcher()

            // Transition to hydrated phase
            phase = .hydrated
            Self.logger.info("✅ Hydration complete, app ready")
        } catch ServiceError.unauthorized {
            // Handle authentication errors by signing out
            Self.logger.error("🔐 Authentication error during hydration - signing out")
            await signOut()
        } catch {
            Self.logger.error("❌ Hydration failed: \(error)")
            self.error = error
            phase = .error
        }
    }

    /// Hydrate user data after authentication
    private func hydrateUserData() async throws {
        Self.logger.info("💧 Hydrating user data")

        // Use HydrationService with the actual hydrate query
        guard let apolloClientService = container.apolloClientService else {
            Self.logger.warning("⚠️ Apollo client service not available for hydration")
            throw ServiceError.operationFailed("Apollo client service not available")
        }

        // Create a GraphQLService instance for HydrationService
        let graphQLService = await MainActor.run {
            GraphQLService(apolloClientService: apolloClientService)
        }

        let hydrationService = await MainActor.run {
            HydrationService(graphQLService: graphQLService)
        }
        let result = try await hydrationService.hydrateUserData()

        Self.logger.info("✅ Hydrated user data")
        Self.logger.info("📊 Found \(result.households.count) households")

        // Use households from the hydration result
        let households = result.households
        let currentUser = result.currentUser

        // Store current user
        self.currentUser = currentUser
        Self.logger.info("📊 Initial user from hydration: \(currentUser.name ?? "Unknown")")
        Self.logger.info("   First: '\(currentUser.firstName)', Last: '\(currentUser.lastName)', Display: '\(currentUser.displayName ?? "nil")'")

        // Check if user needs onboarding based on missing user info OR no households
        let needsUserInfo = currentUser.firstName.isEmpty || currentUser.lastName.isEmpty
        let hasNoHouseholds = households.isEmpty

        if needsUserInfo || hasNoHouseholds {
            needsOnboarding = true
            if needsUserInfo {
                Self.logger.info("📋 User needs onboarding - missing name information")
            }
            if hasNoHouseholds {
                Self.logger.info("🏠 User needs onboarding - no households")
            }
        } else {
            needsOnboarding = false

            // Restore last selected household or use first
            let lastSelectedId = await userPreferencesService?.getLastSelectedHouseholdId()
            if let lastSelectedId = lastSelectedId,
               let household = households.first(where: { $0.id == lastSelectedId })
            {
                currentHousehold = household
            } else {
                currentHousehold = households.first
            }

            Self.logger.info("✅ Hydration complete. Selected household: \(currentHousehold?.name ?? "none")")
        }
    }

    /// Setup reactive household watcher to keep AppState in sync with Apollo cache
    private func setupHouseholdWatcher() {
        guard let householdService = householdService else {
            Self.logger.warning("⚠️ Cannot setup household watcher - HouseholdService not available")
            return
        }

        // Only setup if we have a current household to watch
        guard let currentHousehold = currentHousehold else {
            Self.logger.debug("🔍 No current household to watch yet")
            return
        }

        Self.logger.info("👁️ Setting up reactive household watcher for: \(currentHousehold.name)")

        // Use watchHousehold(id:) with the actual household ID
        currentHouseholdWatch = householdService.watchHousehold(id: currentHousehold.id)

        // Set up observation to detect changes
        Task { @MainActor in
            guard let watch = currentHouseholdWatch else { return }

            // Store the current name to detect changes
            var lastKnownName = currentHousehold.name

            // Use withObservationTracking to observe changes to the WatchedResult
            while !Task.isCancelled {
                withObservationTracking {
                    // Access the watched value to register observation
                    _ = watch.value
                    _ = watch.error
                    _ = watch.isLoading
                } onChange: {
                    // This closure is called when the observed values change
                    Task { @MainActor in
                        // Check if we have a valid updated household
                        if let updatedHousehold = watch.value,
                           updatedHousehold.id == self.currentHousehold?.id,
                           updatedHousehold.name != lastKnownName
                        {
                            Self.logger.info("🔄 Household watcher: detected name change from '\(lastKnownName)' to '\(updatedHousehold.name)'")
                            self.currentHousehold = updatedHousehold
                            lastKnownName = updatedHousehold.name
                        }

                        // Log errors but don't spam - only log once per error type
                        if let error = watch.error {
                            Self.logger.warning("⚠️ Household watcher error: \(error)")
                        }
                    }
                }

                // Small delay to prevent tight loop
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
        }

        Self.logger.info("✅ Household watcher setup complete")
    }

    // MARK: - Computed Properties

    public var canRetry: Bool {
        error != nil
    }

    public var isLoading: Bool {
        switch phase {
        case .launching, .initializing, .authenticating, .hydrating, .signingOut:
            return true
        default:
            return false
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let householdChanged = Notification.Name("householdChanged")
}

// MARK: - App Errors

public enum AppError: LocalizedError {
    case initializationFailed
    case servicesUnavailable
    case authenticationFailed
    case hydrationFailed

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize app"
        case .servicesUnavailable:
            return "Services are temporarily unavailable"
        case .authenticationFailed:
            return "Authentication failed"
        case .hydrationFailed:
            return "Failed to load user data"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed, .servicesUnavailable:
            return "Please try again later"
        case .authenticationFailed:
            return "Please sign in again"
        case .hydrationFailed:
            return "Check your internet connection and try again"
        }
    }
}
