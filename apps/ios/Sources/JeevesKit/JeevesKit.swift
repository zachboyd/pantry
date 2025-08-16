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
    @Environment(\.appState) private var appState
    @Environment(\.themeManager) private var themeManager

    public init() {}

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
    let appState: AppState

    // Animation state for household switching
    @State private var switchCounter = 0 // Track each switch uniquely
    @State private var useSecondView = false // Flip-flop between two views
    @State private var oldActiveView = false // Track which view was active before animation

    // Animation control
    @State private var isAnimating = false
    @State private var currentPhase: AnimationPhase = .completed

    // Animation phases for PhaseAnimator - discrete steps in order
    enum AnimationPhase: CaseIterable {
        case waiting // Step 0: Wait before starting (0.3s delay)
        case blurring // Step 1: Apply blur effect
        case scalingDown // Step 2: Scale down to 0.9
        case sliding // Step 3: Slide views horizontally
        case scalingUp // Step 4: Scale back up to 1.0
        case unblurring // Step 5: Remove blur effect
        case completed // Step 6: Animation finished

        var scale: CGFloat {
            switch self {
            case .waiting, .blurring: 1.0
            case .scalingDown, .sliding: 0.9
            case .scalingUp, .unblurring, .completed: 1.0
            }
        }

        var blur: CGFloat {
            switch self {
            case .waiting: 0
            case .blurring, .scalingDown, .sliding, .scalingUp: 10
            case .unblurring, .completed: 0
            }
        }

        var isBlurred: Bool {
            blur > 0
        }
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
                        // Main tab view with manual animation control
                        GeometryReader { geometry in
                            ZStack {
                                // First view
                                if !useSecondView || isAnimating {
                                    MainTabView()
                                        .id("view-1")
                                        .scaleEffect(isAnimating ? currentPhase.scale : 1.0)
                                        .offset(x: calculateOffset(
                                            isActiveView: !useSecondView,
                                            phase: currentPhase,
                                            screenWidth: geometry.size.width,
                                        ))
                                        .opacity(isAnimating && useSecondView && currentPhase == .sliding ? 0.95 : 1.0)
                                }

                                // Second view
                                if useSecondView || isAnimating {
                                    MainTabView()
                                        .id("view-2")
                                        .scaleEffect(isAnimating ? currentPhase.scale : 1.0)
                                        .offset(x: calculateOffset(
                                            isActiveView: useSecondView,
                                            phase: currentPhase,
                                            screenWidth: geometry.size.width,
                                        ))
                                        .opacity(isAnimating && !useSecondView && currentPhase == .sliding ? 0.95 : 1.0)
                                }
                            }
                            .blur(radius: isAnimating ? currentPhase.blur : 0)
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

            // Loading overlay when switching household
            if currentPhase.isBlurred {
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
                triggerHouseholdSwitchAnimation()
            }
            // Remove the else clause - let the animation complete on its own timeline
        }
    }

    // MARK: - Animation Control Methods

    private func calculateOffset(isActiveView: Bool, phase: AnimationPhase, screenWidth: CGFloat) -> CGFloat {
        // When not animating, just position views normally
        if !isAnimating {
            return isActiveView ? 0 : screenWidth
        }

        // Determine if this is the old view
        // Key insight: After toggle, the currently active view (isActiveView = true) is NEW
        // The inactive view (isActiveView = false) is OLD
        // BUT isActiveView is relative to each view's calculation

        // For view-1: isActiveView = !useSecondView
        // For view-2: isActiveView = useSecondView

        // Simple solution: The old view is the one that WAS active
        // View-1 was active when useSecondView was false (stored in oldActiveView)
        // View-2 was active when useSecondView was true (stored in oldActiveView)

        // Check if this is view-1 or view-2, then check if it was active
        let isView1 = (isActiveView == !useSecondView)
        let isOldView = isView1 ? !oldActiveView : oldActiveView

        // During animation, handle phases based on whether it's the old or new view
        switch phase {
        case .waiting, .blurring, .scalingDown:
            // Old view stays at center, new view waits off-screen right
            return isOldView ? 0 : screenWidth
        case .sliding:
            // BOTH views slide left: old goes from 0 to -screenWidth, new goes from screenWidth to 0
            return isOldView ? -screenWidth : 0
        case .scalingUp, .unblurring:
            // Keep views in their final positions after slide
            return isOldView ? -screenWidth : 0
        case .completed:
            // Reset positions - active view at center, inactive off-screen RIGHT
            return isActiveView ? 0 : screenWidth
        }
    }

    private func triggerHouseholdSwitchAnimation() {
        // Prevent re-triggering if already animating
        guard !isAnimating else { return }

        isAnimating = true
        switchCounter += 1

        // Save which view was active before we toggle
        oldActiveView = useSecondView

        // Toggle the view BEFORE animation starts so the new view is ready
        useSecondView.toggle()

        // Start with waiting phase (no animation needed)
        currentPhase = .waiting

        // Use DispatchQueue for the initial wait since there's no animation
        DispatchQueue.main.asyncAfter(deadline: .now() + TransitionConstants.householdSwitchWaitDuration) {
            // Phase 2: Blurring
            withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchBlurInDuration)) {
                currentPhase = .blurring
            } completion: {
                // Phase 3: Scaling down
                withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchScaleDownDuration)) {
                    currentPhase = .scalingDown
                } completion: {
                    // Phase 4: Sliding
                    withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchSlideDuration)) {
                        currentPhase = .sliding
                    } completion: {
                        // Phase 5: Scaling up
                        withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchScaleUpDuration)) {
                            currentPhase = .scalingUp
                        } completion: {
                            // Phase 6: Unblurring
                            withAnimation(.easeInOut(duration: TransitionConstants.householdSwitchBlurOutDuration)) {
                                currentPhase = .unblurring
                            } completion: {
                                // Phase 7: Complete
                                currentPhase = .completed
                                isAnimating = false
                            }
                        }
                    }
                }
            }
        }
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
