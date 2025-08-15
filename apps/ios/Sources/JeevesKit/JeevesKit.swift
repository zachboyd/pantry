import Foundation
import SwiftUI

// MARK: - Household Switch Animation Modifier

struct HouseholdSwitchAnimationModifier: ViewModifier {
    let isActiveView: Bool
    let animationPhase: AppRootContentView.HouseholdSwitchPhase
    let switchOffset: CGFloat
    let switchScale: CGFloat
    let hideInactiveView: Bool
    let screenWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(animationPhase != .idle ? switchScale : 1.0)
            .offset(x: calculateOffset())
            .opacity(shouldHide() ? 0 : 1)
            .animation(
                animationPhase == .sliding ?
                    .easeInOut(duration: TransitionConstants.householdSwitchSlideDuration) :
                    nil,
                value: switchOffset,
            )
            .animation(nil, value: hideInactiveView)
    }

    private func calculateOffset() -> CGFloat {
        if isActiveView {
            switchOffset
        } else {
            switchOffset + screenWidth
        }
    }

    private func shouldHide() -> Bool {
        hideInactiveView && !isActiveView
    }
}

extension View {
    func householdSwitchAnimation(
        isActiveView: Bool,
        animationPhase: AppRootContentView.HouseholdSwitchPhase,
        switchOffset: CGFloat,
        switchScale: CGFloat,
        hideInactiveView: Bool,
        screenWidth: CGFloat,
    ) -> some View {
        modifier(HouseholdSwitchAnimationModifier(
            isActiveView: isActiveView,
            animationPhase: animationPhase,
            switchOffset: switchOffset,
            switchScale: switchScale,
            hideInactiveView: hideInactiveView,
            screenWidth: screenWidth,
        ))
    }
}

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

    // Animation state for household switching
    @State private var householdSwitchOffset: CGFloat = 0
    @State private var householdSwitchScale: CGFloat = 1.0
    @State private var animationPhase: HouseholdSwitchPhase = .idle
    @State private var shouldShowBlur = false
    @State private var switchCounter = 0 // Track each switch uniquely
    @State private var useSecondView = false // Flip-flop between two views
    @State private var hideInactiveView = false // Hide inactive view during reset

    enum HouseholdSwitchPhase {
        case idle
        case blurring
        case sliding
        case scalingUp
        case waitingForSwitchComplete
    }

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
                        // Main tab view with household switching animation
                        GeometryReader { geometry in
                            ZStack {
                                // First view - active when useSecondView is false
                                if !useSecondView || animationPhase != .idle {
                                    MainTabView()
                                        .id("view-1")
                                        .householdSwitchAnimation(
                                            isActiveView: !useSecondView,
                                            animationPhase: animationPhase,
                                            switchOffset: householdSwitchOffset,
                                            switchScale: householdSwitchScale,
                                            hideInactiveView: hideInactiveView,
                                            screenWidth: geometry.size.width,
                                        )
                                }

                                // Second view - active when useSecondView is true
                                if useSecondView || animationPhase != .idle {
                                    MainTabView()
                                        .id("view-2")
                                        .householdSwitchAnimation(
                                            isActiveView: useSecondView,
                                            animationPhase: animationPhase,
                                            switchOffset: householdSwitchOffset,
                                            switchScale: householdSwitchScale,
                                            hideInactiveView: hideInactiveView,
                                            screenWidth: geometry.size.width,
                                        )
                                }
                            }
                        }
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
            .blur(radius: shouldShowBlur ? 10 : 0)
            .animation(.easeInOut(duration: TransitionConstants.householdSwitchBlurDuration), value: shouldShowBlur)

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
        .onChange(of: appState.isSwitchingHousehold) { oldValue, newValue in
            if !oldValue, newValue, appState.phase == .hydrated, !appState.needsOnboarding {
                // Transition from false to true - start animation
                switchCounter += 1
                shouldShowBlur = true
                triggerHouseholdSwitchAnimation()
            } else if oldValue, !newValue {
                // Transition from true to false - check if we can unblur
                checkAndCompleteAnimation()
            }
        }
    }

    // MARK: - Animation Control Methods

    private func triggerHouseholdSwitchAnimation() {
        // Prevent re-triggering if already animating
        guard animationPhase == .idle else { return }

        let currentSwitch = switchCounter

        // Phase 1: Blur is already animating (triggered by shouldShowBlur)
        animationPhase = .blurring

        // Phase 2: After blur completes, start the slide animation
        DispatchQueue.main.asyncAfter(deadline: .now() + TransitionConstants.householdSwitchBlurDuration) {
            guard switchCounter == currentSwitch else { return } // Cancelled by newer switch

            // Scale down to 90%
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                householdSwitchScale = TransitionConstants.householdSwitchScaleFactor
            }
            animationPhase = .sliding

            // Start sliding after spring animation completes (~0.35 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard switchCounter == currentSwitch else { return } // Cancelled by newer switch

                // Slide the views - both views move together
                // The current active view slides out to the left
                // The inactive view (which will become active) slides in from the right
                withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchSlideDuration)) {
                    householdSwitchOffset = -UIScreen.main.bounds.width
                }

                // Phase 3: After slide completes, flip to the new view and scale back up
                DispatchQueue.main.asyncAfter(deadline: .now() + TransitionConstants.householdSwitchSlideDuration) {
                    guard switchCounter == currentSwitch else { return } // Cancelled by newer switch

                    // Flip to the other view and reset offset without hiding
                    useSecondView.toggle()
                    householdSwitchOffset = 0

                    animationPhase = .scalingUp
                    // Use a spring animation with higher damping for smoother scaling
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        householdSwitchScale = 1.0
                    }

                    // After scaling completes, check if we can unblur
                    // Spring animation takes ~0.4 seconds to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        guard switchCounter == currentSwitch else { return } // Cancelled by newer switch

                        // Animation complete
                        animationPhase = .waitingForSwitchComplete

                        // Check if we can unblur
                        checkAndCompleteAnimation()
                    }
                }
            }
        }
    }

    private func checkAndCompleteAnimation() {
        // Only unblur if animation is complete AND switching is done
        if animationPhase == .waitingForSwitchComplete, !appState.isSwitchingHousehold {
            shouldShowBlur = false
            animationPhase = .idle
        }
        // If still switching, the animation will wait
    }

    private func resetHouseholdSwitchAnimation() {
        // Clean reset for next animation
        householdSwitchOffset = 0
        householdSwitchScale = 1.0
        // Don't reset animationPhase here - let checkAndCompleteAnimation handle it
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
