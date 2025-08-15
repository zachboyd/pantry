import Foundation
import SwiftUI

/// Main entry point for JeevesKit framework
public struct JeevesKit {
    public static let version = "1.0.0"

    private init() {}
}

// MARK: - Temporary Placeholder Views

// These will be replaced with actual implementations in future phases

public struct AppRootView: View {
    private static let logger = Logger.app

    @Environment(\.appState) private var appState
    @Environment(\.themeManager) private var themeManager

    public init() {
        Self.logger.debug("🏁 AppRootView initialized")
    }

    public var body: some View {
        if let appState {
            AppRootContentView(appState: appState)
        } else {
            StandardLoadingView(showLogo: true)
        }
    }
}

// Separate view that directly observes AppState
struct AppRootContentView: View {
    private static let logger = Logger.app
    let appState: AppState

    var body: some View {
        ZStack {
            // Main content
            Group {
                switch appState.phase {
                case .launching:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition(duration: TransitionConstants.launchToAuthDuration)
                        .zIndex(1)

                case .initializing:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition()
                        .zIndex(2)

                case .authenticating:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition()
                        .zIndex(3)

                case .unauthenticated:
                    AuthenticationContainerView()
                        .fadeTransition(duration: TransitionConstants.authToMainDuration)
                        .zIndex(4)

                case .authenticated:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition()
                        .zIndex(5)

                case .hydrating:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition()
                        .zIndex(6)

                case .hydrated:
                    if appState.needsOnboarding {
                        OnboardingContainerView(
                            onSignOut: {
                                await appState.signOut()
                            },
                            onComplete: { householdId in
                                await appState.completeOnboarding(householdId: householdId)
                            },
                        )
                        .fadeTransition(duration: TransitionConstants.authToMainDuration)
                        .zIndex(7)
                    } else {
                        MainTabView()
                            .fadeTransition(duration: TransitionConstants.authToMainDuration)
                            .zIndex(8)
                    }

                case .signingOut:
                    StandardLoadingView(showLogo: true)
                        .fadeTransition()
                        .zIndex(9)

                case .error:
                    ErrorView(appState: appState)
                        .fadeTransition(duration: TransitionConstants.errorTransitionDuration)
                        .zIndex(10)
                }
            }
            .blur(radius: appState.isSwitchingHousehold ? 10 : 0)
            .animation(.easeInOut(duration: 0.3), value: appState.isSwitchingHousehold)

            // Loading overlay when switching household
            if appState.isSwitchingHousehold {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(100)

                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text(L("household.switching"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
                .zIndex(101)
            }
        }
        .animation(TransitionConstants.standardEasing(duration: TransitionConstants.totalTransitionDuration), value: appState.phase)
        .tint(DesignTokens.Colors.Primary.base)
        // Theme is now applied at WindowGroup level in JeevesApp - no need to apply here
    }
}

struct ErrorView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text(L("error.generic_title"))
                .font(.largeTitle)
                .fontWeight(.bold)

            if let error = appState.error {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if appState.canRetry {
                PrimaryButton(L("error.try_again")) {
                    Task {
                        await appState.retry()
                    }
                }
            }
        }
        .padding()
    }
}

public struct StandardLoadingView: View {
    let showLogo: Bool
    @State private var isPulsing = false

    public init(showLogo: Bool = true) {
        self.showLogo = showLogo
    }

    public var body: some View {
        VStack(spacing: 20) {
            if showLogo {
                Image(systemName: AppSections.emptyStateIcon(for: .pantry))
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .opacity(isPulsing ? 0.8 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isPulsing,
                    )
            }

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

            Text(L("app.loading"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isPulsing = true
        }
        .onDisappear {
            // Cancel animation by resetting the state
            isPulsing = false
        }
    }
}
