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
        case .launching: "launching"
        case .initializing: "initializing"
        case .authenticating: "authenticating"
        case .unauthenticated: "unauthenticated"
        case .authenticated: "authenticated"
        case .hydrating: "hydrating"
        case .hydrated: "hydrated"
        case .signingOut: "signingOut"
        case .error: "error"
        }
    }
}

/// Central app state implementation using DependencyContainer for services
@Observable @MainActor
public final class AppState {
    private static let logger = Logger.app

    // MARK: - State Properties

    private var _phase: AppPhase = .launching
    public var phase: AppPhase { _phase }

    public private(set) var needsOnboarding: Bool = false
    public private(set) var currentHousehold: Household?
    public private(set) var currentUser: User?
    public private(set) var error: Error?
    public private(set) var isInitialized: Bool = false

    // MARK: - Phase Transition Management

    private var lastPhaseTransition: Date = .init()
    private var phaseTransitionQueue: [AppPhase] = []
    private var isProcessingPhaseTransition: Bool = false
    private let minimumPhaseDuration: TimeInterval = 0.1 // 100ms minimum between transitions
    private let minimumLoadingDuration: TimeInterval = 0.15 // 200ms minimum for loading states

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

    public var subscriptionService: (any SubscriptionServiceProtocol)? {
        container.subscriptionService
    }

    // MARK: - Initialization

    public init() {
        // AppState initialized
    }

    /// Perform early synchronous initialization checks
    /// This should be called immediately after AppState creation to check for existing auth
    public func performEarlyAuthCheck() {
        // Performing early auth check...

        // Create a temporary auth token manager to check for stored tokens
        // This is a lightweight synchronous check that doesn't require full service initialization
        let tokenManager = AuthTokenManager()
        if let storedToken = tokenManager.loadToken(), storedToken.isValid {
            // Found valid stored token during early check
            // Set phase to authenticated early to avoid showing unnecessary loading
            // The full initialization will still happen, but UI won't flash loading state
            setPhaseImmediate(.authenticating) // Will quickly transition to authenticated
        } else {
            // No valid stored token found during early check
        }
    }

    // MARK: - Lifecycle Methods

    /// Initialize the app and all services
    public func initialize() async {
        // Prevent duplicate initialization
        guard !isInitialized else {
            // App already initialized, skipping
            return
        }

        // Starting app initialization

        do {
            setPhaseImmediate(.initializing)

            // Initialize services
            try await container.initializeServices()

            // Check authentication state
            await setPhase(.authenticating)
            // Checking for authService...
            if let authService {
                // AuthService found, checking authentication state
                let isAuthenticated = authService.isAuthenticated
                // Authentication state check

                if isAuthenticated {
                    // Don't immediately transition to authenticated
                    // Instead, start hydration and let it manage phase transitions
                    // User is authenticated, starting hydration...
                    await startHydration()
                } else {
                    await setPhase(.unauthenticated)
                }
            } else {
                Self.logger.warning("⚠️ AuthService not found, setting phase to unauthenticated")
                await setPhase(.unauthenticated)
            }

            isInitialized = true
            // App initialization complete

        } catch {
            Self.logger.error("❌ App initialization failed: \(error)")
            self.error = error
            await setPhase(.error)
        }
    }

    /// Sign out the current user
    public func signOut() async {
        // Starting sign out
        await setPhase(.signingOut)

        // Stop all subscriptions before signing out
        subscriptionService?.stopAllSubscriptions()

        do {
            // Attempt to sign out from auth service
            if let authService {
                try await authService.signOut()
                // Network sign out successful
            }

            // Clear all services
            await container.clearServices()

        } catch {
            Self.logger.warning("⚠️ Network sign out failed, but continuing with local sign out: \(error)")
            // Don't set error state - local sign out should still proceed
        }

        // Always clear local state regardless of network sign out success
        // Clear reactive watchers (they'll be cancelled when tasks are cancelled)

        // Clear user data
        currentHousehold = nil
        currentUser = nil
        needsOnboarding = false

        // Always go to unauthenticated state - user should be able to sign in again
        // even if network sign out failed
        await setPhase(.unauthenticated)
        // Sign out complete - user can sign in again
    }

    /// Retry after an error
    public func retry() async {
        // Retrying after error
        error = nil
        await initialize()
    }

    /// Handle successful authentication
    public func handleAuthenticated() async {
        // Handling successful authentication

        // Log current auth state
        if authService != nil {
            // Auth state check - verifying authentication
        }

        // Update to authenticated state
        await setPhase(.authenticated)
        // Successfully transitioned to authenticated state

        // Start hydration process
        await startHydration()
    }

    /// Update the selected household
    public func selectHousehold(_ household: Household?) {
        // Selecting household
        currentHousehold = household

        // Setup watcher for the new household to keep it reactive
        // This will automatically stop any existing watcher first
        setupHouseholdWatcher()

        // Persist selection
        if let household {
            Task {
                await userPreferencesService?.setLastSelectedHouseholdId(household.id)
            }
        }
    }

    /// Switch to a different household
    public func switchHousehold(to household: Household) async {
        // Switching to household

        // Update current household
        selectHousehold(household)

        // Reset any tab-specific state
        // This ensures all tabs reload with the new household context
        NotificationCenter.default.post(name: .householdChanged, object: household)

        // Household switch complete
    }

    /// Refresh the current user from the backend
    public func refreshCurrentUser() async {
        // Refreshing current user

        if let userService {
            do {
                if let refreshedUser = try await userService.getCurrentUser() {
                    // User refreshed
                    currentUser = refreshedUser
                }
            } catch {
                Self.logger.error("❌ Failed to refresh user: \(error)")
            }
        }
    }

    /// Complete onboarding with a selected household
    public func completeOnboarding(householdId: String) async {
        // Completing onboarding with household

        // Get the household
        if let householdService,
           let userService
        {
            do {
                // Refresh the current user to get updated name
                if let refreshedUser = try await userService.getCurrentUser() {
                    // Refreshed user after onboarding
                    currentUser = refreshedUser
                }

                let household = try await householdService.getHousehold(id: householdId)
                currentHousehold = household
                needsOnboarding = false
                await setPhase(.hydrated)

                // Persist selection
                await userPreferencesService?.setLastSelectedHouseholdId(householdId)

                // Onboarding completed successfully
            } catch {
                Self.logger.error("❌ Failed to complete onboarding: \(error)")
                self.error = error
            }
        }
    }

    // MARK: - Private Methods

    /// Start the hydration process
    private func startHydration() async {
        // Starting hydration process

        // First transition to authenticated to show we're past login
        // This allows UI to show authenticated state while loading data
        await setPhase(.authenticated)

        // Small delay to ensure UI updates before heavy hydration work
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Now transition to hydrating phase for data loading
        await setPhase(.hydrating)

        do {
            // First, get the auth user ID from auth service
            guard let authService,
                  let authUserId = authService.currentAuthUser?.id
            else {
                Self.logger.error("No authenticated user found for service initialization")
                throw AppError.authenticationFailed
            }

            // Initialize all services for the authenticated user
            // NOTE: We're using auth user ID here since services need it for API calls
            // Initializing all services for authenticated user

            // Log token status before initialization
            if authService.tokenManager.loadToken() != nil {
                // Token status verified before service init
            } else {
                Self.logger.warning("⚠️ No token found before service initialization")
            }

            try await container.initializeForAuthUser(authUserId)
            // All services initialized successfully

            // CRITICAL: Ensure session cookies are set after authentication
            // This is necessary for GraphQL requests to work properly
            if let apolloClientService = container.apolloClientService {
                // Ensuring session cookies are set for GraphQL requests
                apolloClientService.ensureSessionCookies()

                // Verify cookies are actually set
                if let graphQLURL = URL(string: "http://localhost:3001/graphql") {
                    if HTTPCookieStorage.shared.cookies(for: graphQLURL) != nil {
                        // Cookies verified after ensureSessionCookies
                    } else {
                        Self.logger.warning("⚠️ No cookies found after ensureSessionCookies")
                    }
                }
            }

            // Don't setup cache observers yet - wait until after hydration
            // so we have initial data to observe

            // Load user permissions
            // Loading user permissions
            await authService.loadUserPermissions()
            // User permissions loaded

            // Execute the hydrate query
            try await hydrateUserData()

            // Setup reactive household watcher AFTER hydration
            // This ensures currentHousehold stays in sync with Apollo cache changes
            setupHouseholdWatcher()

            // Start subscriptions after successful hydration
            if let subscriptionService {
                Self.logger.info("📡 Starting real-time subscriptions")
                do {
                    try await subscriptionService.subscribeToUserUpdates()
                    Self.logger.info("✅ Real-time subscriptions started")
                } catch {
                    Self.logger.warning("⚠️ Failed to start subscriptions: \(error)")
                    // Non-critical - continue without subscriptions
                }
            }

            // Transition to hydrated phase
            await setPhase(.hydrated)
            // Hydration complete, app ready with real-time updates
        } catch ServiceError.unauthorized {
            // Handle authentication errors by signing out
            Self.logger.error("Authentication error during hydration - signing out")
            await signOut()
        } catch {
            Self.logger.error("Hydration failed: \(error)")
            self.error = error
            await setPhase(.error)
        }
    }

    /// Hydrate user data after authentication
    private func hydrateUserData() async throws {
        // Hydrating user data

        // Use the existing GraphQLService from the container which has proper auth setup
        guard let graphQLService = container.graphQLService else {
            Self.logger.warning("⚠️ GraphQL service not available for hydration")
            throw ServiceError.operationFailed("GraphQL service not available")
        }

        // Use the existing HydrationService from the container if available,
        // or create one with the properly configured GraphQLService
        let hydrationService: HydrationService = if let existingHydrationService = container.hydrationService {
            existingHydrationService
            // Using existing HydrationService from container
        } else {
            await MainActor.run {
                HydrationService(graphQLService: graphQLService)
            }
            // Created temporary HydrationService for hydration
        }
        let result = try await hydrationService.hydrateUserData()

        // Hydrated user data

        // Use households from the hydration result
        let households = result.households
        let currentUser = result.currentUser

        // Store current user
        self.currentUser = currentUser
        // Initial user data loaded from hydration

        // Check if user needs onboarding based on missing user info OR no households
        let needsUserInfo = currentUser.firstName.isEmpty || currentUser.lastName.isEmpty
        let hasNoHouseholds = households.isEmpty

        if needsUserInfo || hasNoHouseholds {
            needsOnboarding = true
            if needsUserInfo {
                // User needs onboarding - missing name information
            }
            if hasNoHouseholds {
                // User needs onboarding - no households
            }
        } else {
            needsOnboarding = false

            // Restore last selected household or use first
            let lastSelectedId = await userPreferencesService?.getLastSelectedHouseholdId()
            if let lastSelectedId,
               let household = households.first(where: { $0.id == lastSelectedId })
            {
                currentHousehold = household
            } else {
                currentHousehold = households.first
            }

            // Hydration complete
        }
    }

    /// Setup reactive household watcher to keep AppState in sync with Apollo cache
    private func setupHouseholdWatcher() {
        guard let householdService else {
            Self.logger.warning("⚠️ Cannot setup household watcher - HouseholdService not available")
            return
        }

        // Only setup if we have a current household to watch
        guard let currentHousehold else {
            // No current household to watch yet
            return
        }

        // Setting up reactive household watcher

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
                            // Household watcher: detected name change
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

        // Household watcher setup complete
    }

    // MARK: - Phase Transition Management Methods

    /// Set phase immediately (synchronous) - use for critical transitions
    private func setPhaseImmediate(_ newPhase: AppPhase) {
        // Phase transition (immediate)
        _phase = newPhase
        lastPhaseTransition = Date()
    }

    /// Set phase with debouncing to prevent rapid transitions
    private func setPhase(_ newPhase: AppPhase) async {
        // Check if this is a loading phase that needs minimum duration
        let wasLoadingPhase = isLoadingPhase(phase)

        // Calculate time since last transition
        let timeSinceLastTransition = Date().timeIntervalSince(lastPhaseTransition)

        // Determine minimum duration needed
        var minimumDuration = minimumPhaseDuration
        if wasLoadingPhase {
            // If we're transitioning FROM a loading state, ensure it was shown long enough
            minimumDuration = max(minimumDuration, minimumLoadingDuration)
        }

        // If not enough time has passed, wait before transitioning
        if timeSinceLastTransition < minimumDuration {
            let remainingTime = minimumDuration - timeSinceLastTransition
            // Delaying phase transition to prevent rapid changes
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }

        // Queue the phase transition if one is already processing
        if isProcessingPhaseTransition {
            // Queueing phase transition
            phaseTransitionQueue.append(newPhase)
            return
        }

        // Process the phase transition
        isProcessingPhaseTransition = true
        defer {
            isProcessingPhaseTransition = false
            // Process any queued transitions
            Task {
                await processQueuedPhaseTransitions()
            }
        }

        // Update the phase
        // Phase transition
        _phase = newPhase
        lastPhaseTransition = Date()
    }

    /// Process any queued phase transitions
    private func processQueuedPhaseTransitions() async {
        while !phaseTransitionQueue.isEmpty {
            let nextPhase = phaseTransitionQueue.removeFirst()
            await setPhase(nextPhase)
        }
    }

    /// Check if a phase is a loading phase that needs minimum display time
    private func isLoadingPhase(_ phase: AppPhase) -> Bool {
        switch phase {
        case .launching, .initializing, .authenticating, .hydrating, .signingOut:
            true
        default:
            false
        }
    }

    // MARK: - Computed Properties

    public var canRetry: Bool {
        error != nil
    }

    public var isLoading: Bool {
        switch phase {
        case .launching, .initializing, .authenticating, .hydrating, .signingOut:
            true
        default:
            false
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
            "Failed to initialize app"
        case .servicesUnavailable:
            "Services are temporarily unavailable"
        case .authenticationFailed:
            "Authentication failed"
        case .hydrationFailed:
            "Failed to load user data"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed, .servicesUnavailable:
            "Please try again later"
        case .authenticationFailed:
            "Please sign in again"
        case .hydrationFailed:
            "Check your internet connection and try again"
        }
    }
}
