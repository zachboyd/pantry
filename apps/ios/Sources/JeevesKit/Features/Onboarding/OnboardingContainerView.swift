/*
 OnboardingContainerView.swift
 JeevesKit

 Intelligent onboarding flow that adapts to user state
 */

import SwiftUI

/// Container for onboarding flow states
public struct OnboardingContainerView: View {
    private static let logger = Logger(category: "OnboardingContainerView")

    @Environment(\.safeViewModelFactory) private var viewModelFactory
    @State private var viewModel: OnboardingContainerViewModel?
    @State private var userInfoViewModel: UserInfoViewModel?
    @State private var householdCreationViewModel: HouseholdCreationViewModel?

    let onSignOut: () async -> Void
    let onComplete: (LowercaseUUID) async -> Void

    public init(onSignOut: @escaping () async -> Void, onComplete: @escaping (LowercaseUUID) async -> Void) {
        self.onSignOut = onSignOut
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Consistent background color with sign in/up views
                DesignTokens.Colors.systemBackground()
                    .ignoresSafeArea()

                Group {
                    if let viewModel {
                        if viewModel.state.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                                .fadeTransition()
                        } else {
                            ZStack {
                                switch viewModel.state.currentStep {
                                case .loading:
                                    // Loading state handled above
                                    EmptyView()

                                case .userInfo:
                                    if let userInfoViewModel {
                                        UserInfoView(
                                            viewModel: userInfoViewModel,
                                            onComplete: {
                                                withAnimation(TransitionConstants.smoothSpring) {
                                                    viewModel.handleUserInfoComplete()
                                                }
                                            },
                                        )
                                        .slideAndFadeTransition(edge: .trailing)
                                        .zIndex(1)
                                    }

                                case .householdCreation:
                                    if let householdCreationViewModel {
                                        HouseholdCreationView(
                                            viewModel: householdCreationViewModel,
                                            onBack: nil, // No back button in simplified flow
                                            onComplete: { (householdId: LowercaseUUID) in
                                                withAnimation(TransitionConstants.smoothSpring) {
                                                    viewModel.handleHouseholdCreated(householdId: householdId)
                                                }
                                                if let completionId = viewModel.getCompletionHouseholdId() {
                                                    completeOnboarding(with: completionId)
                                                }
                                            },
                                        )
                                        .slideAndFadeTransition(edge: .trailing)
                                        .zIndex(2)
                                    }

                                case .complete:
                                    // This shouldn't be shown, but just in case
                                    VStack(spacing: DesignTokens.Spacing.lg) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(DesignTokens.Colors.Status.success)

                                        Text(L("onboarding.complete.title"))
                                            .font(DesignTokens.Typography.Semantic.pageTitle())

                                        Text(L("onboarding.complete.subtitle"))
                                            .font(DesignTokens.Typography.Semantic.body())
                                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                                    }
                                    .fadeAndScaleTransition()
                                    .zIndex(3)
                                    .onAppear {
                                        // Auto-complete after a brief moment
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if let completionId = viewModel.getCompletionHouseholdId() {
                                                completeOnboarding(with: completionId)
                                            }
                                        }
                                    }
                                }
                            }
                            .animation(TransitionConstants.gentleEasing(duration: TransitionConstants.onboardingStepDuration), value: viewModel.state.currentStep)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .fadeTransition()
                            .onAppear {
                                setupViewModels()
                            }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("sign.out")) {
                        Task {
                            // Use only AppState.signOut() to avoid dual sign-out race condition
                            // AppState is the single source of truth for authentication state
                            await onSignOut()
                        }
                    }
                    .font(DesignTokens.Typography.Semantic.body())
                    .foregroundColor(DesignTokens.Colors.Primary.base)
                }
            }
        }
        .task {
            if viewModel == nil {
                setupViewModels()
            }
            await viewModel?.onAppear()
        }
    }

    private func completeOnboarding(with householdId: LowercaseUUID) {
        Task {
            await onComplete(householdId)
        }
    }

    private func setupViewModels() {
        guard let factory = viewModelFactory else { return }

        do {
            viewModel = try factory.makeOnboardingContainerViewModel()
            userInfoViewModel = try factory.makeUserInfoViewModel(currentUser: viewModel?.state.currentUser)
            householdCreationViewModel = try factory.makeHouseholdCreationViewModel()
        } catch {
            Logger.ui.error("Failed to create view models: \(error)")
        }
    }
}

/// Onboarding flow steps for the container view
enum OnboardingFlowStep {
    case loading
    case userInfo
    case householdCreation
    case complete
}
