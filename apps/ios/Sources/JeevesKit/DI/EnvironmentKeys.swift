import SwiftUI

// MARK: - Environment Keys

private let logger = Logger.app

private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue: LocalizationManager? = nil
}

private struct UserPreferencesManagerKey: EnvironmentKey {
    static let defaultValue: UserPreferencesManager? = nil
}

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager? = nil
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: (any AuthServiceProtocol)? = nil
}

private struct HouseholdServiceKey: EnvironmentKey {
    static let defaultValue: (any HouseholdServiceProtocol)? = nil
}

private struct ItemServiceKey: EnvironmentKey {
    static let defaultValue: (any ItemServiceProtocol)? = nil
}

private struct ShoppingListServiceKey: EnvironmentKey {
    static let defaultValue: (any ShoppingListServiceProtocol)? = nil
}

private struct NotificationServiceKey: EnvironmentKey {
    static let defaultValue: (any NotificationServiceProtocol)? = nil
}

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

// MARK: - Environment Values Extension

public extension EnvironmentValues {
    /// Core app state - the single source of truth (optional for safe access)
    var appState: AppState? {
        get {
            let appState = self[AppStateKey.self]
            #if DEBUG
                if appState == nil {
                    logger.debug("AppState is nil - environment not yet injected")
                }
            #endif
            return appState
        }
        set {
            #if DEBUG
                logger.debug("Setting appState in environment: \(String(describing: newValue))")
            #endif
            self[AppStateKey.self] = newValue
        }
    }

    /// Localization manager for language switching
    var localizationManager: LocalizationManager? {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }

    /// User preferences manager for theme and settings
    var userPreferencesManager: UserPreferencesManager {
        get {
            guard let manager = self[UserPreferencesManagerKey.self] else {
                // Fallback to new instance if not injected
                return UserPreferencesManager()
            }
            return manager
        }
        set { self[UserPreferencesManagerKey.self] = newValue }
    }

    /// Theme manager for centralized theme management
    var themeManager: ThemeManager {
        get {
            guard let manager = self[ThemeManagerKey.self] else {
                // Fallback to shared instance if not injected
                return ThemeManager.shared
            }
            return manager
        }
        set { self[ThemeManagerKey.self] = newValue }
    }

    /// Authentication service for user authentication (optional for safe access)
    var authService: (any AuthServiceProtocol)? {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    /// Household service for household management (optional for safe access)
    var householdService: (any HouseholdServiceProtocol)? {
        get { self[HouseholdServiceKey.self] }
        set { self[HouseholdServiceKey.self] = newValue }
    }

    /// Item service for pantry management (optional for safe access)
    var itemService: (any ItemServiceProtocol)? {
        get { self[ItemServiceKey.self] }
        set { self[ItemServiceKey.self] = newValue }
    }

    /// Shopping list service for shopping list management (optional for safe access)
    var shoppingListService: (any ShoppingListServiceProtocol)? {
        get { self[ShoppingListServiceKey.self] }
        set { self[ShoppingListServiceKey.self] = newValue }
    }

    /// Notification service for notifications (optional for safe access)
    var notificationService: (any NotificationServiceProtocol)? {
        get { self[NotificationServiceKey.self] }
        set { self[NotificationServiceKey.self] = newValue }
    }

    /// Dependency container for dependency injection (optional for safe access)
    var dependencyContainer: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - Modern View Injection

public extension View {
    /// Inject AppState and basic managers - the only environment injection needed
    func withAppState() -> some View {
        return AppStateProviderView { self }
    }
}

/// Internal view that properly manages AppState lifecycle
private struct AppStateProviderView<Content: View>: View {
    let contentBuilder: () -> Content
    @State private var appState: AppState?
    @State private var isInitializing = false
    @State private var hasCheckedAuth = false

    init(@ViewBuilder contentBuilder: @escaping () -> Content) {
        self.contentBuilder = contentBuilder
        logger.debug("AppStateProviderView init called")
    }

    var body: some View {
        #if DEBUG
            let _ = logger.debug("AppStateProviderView body called - appState is \(appState == nil ? "nil" : "available")")
        #endif

        return Group {
            if let appState = appState {
                #if DEBUG
                    let _ = logger.debug("AppState available, injecting into environment and rendering content")
                #endif
                // Create content AFTER environment is ready
                contentBuilder()
                    .environment(\.appState, appState)
                    .environment(\.dependencyContainer, appState.container)
                    .environment(\.authService, appState.authService)
                    .environment(\.householdService, appState.householdService)
                    .environment(\.itemService, appState.itemService)
                    .environment(\.shoppingListService, appState.shoppingListService)
                    .environment(\.notificationService, appState.notificationService)
                    .environment(\.localizationManager, LocalizationManager())
                    .environment(\.userPreferencesManager, UserPreferencesManager())
                    .environment(\.themeManager, ThemeManager.shared)
                    .environment(\.safeViewModelFactory, SafeViewModelFactory(container: appState.container))
                    .task(id: "appStateInit") {
                        await appState.initialize()
                    }
            } else {
                #if DEBUG
                    let _ = logger.debug("AppState not available yet, showing loading screen")
                #endif
                // Show loading while AppState is being created
                VStack(spacing: 32) {
                    Image(systemName: AppSections.emptyStateIcon(for: .pantry))
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Jeeves")
                        .font(.title2)
                        .fontWeight(.semibold)

                    ProgressView()
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .onAppear {
                    // Use onAppear for immediate synchronous execution
                    guard !hasCheckedAuth else { return }
                    hasCheckedAuth = true

                    #if DEBUG
                        logger.debug("Creating AppState synchronously on appear...")
                    #endif

                    // Create AppState synchronously to avoid race condition
                    // This ensures AppState exists before any UI tries to access it
                    let newAppState = AppState()

                    // Perform early synchronous auth check to prevent loading flash
                    // This checks for stored tokens without full service initialization
                    newAppState.performEarlyAuthCheck()

                    #if DEBUG
                        logger.debug("AppState created with early auth check complete, phase: \(newAppState.phase)")
                    #endif

                    appState = newAppState
                }
            }
        }
    }
}

// MARK: - Utility Manager Placeholders

// These will be replaced with actual implementations in future phases

@MainActor
@Observable
public final class UserPreferencesManager {
    public static let shared = UserPreferencesManager()

    public var notifications: Bool = true
    public var useBiometrics: Bool = false

    public nonisolated init() {}

    public func setNotifications(enabled: Bool) {
        notifications = enabled
    }

    public func setBiometrics(enabled: Bool) {
        useBiometrics = enabled
    }
}
