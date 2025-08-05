/*
 UserInfoView.swift
 PantryKit

 User information collection view for onboarding
 */

import SwiftUI

/// View for collecting user's first and last name during onboarding
public struct UserInfoView: View {
    let viewModel: UserInfoViewModel
    let onComplete: () -> Void
    
    public init(viewModel: UserInfoViewModel, onComplete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            VStack(spacing: DesignTokens.Spacing.md) {
                Text(L("onboarding.user_info.title"))
                    .font(DesignTokens.Typography.Semantic.pageTitle())
                    .multilineTextAlignment(.center)
                
                Text(L("onboarding.user_info.subtitle"))
                    .font(DesignTokens.Typography.Semantic.body())
                    .foregroundColor(DesignTokens.Colors.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignTokens.Spacing.xl)
            
            VStack(spacing: DesignTokens.Spacing.lg) {
                FormTextField.name(
                    label: L("onboarding.user_info.first_name"),
                    placeholder: L("onboarding.user_info.first_name.placeholder"),
                    text: Binding(
                        get: { viewModel.state.firstName },
                        set: { viewModel.updateFirstName($0) }
                    ),
                    textContentType: .givenName
                )
                
                FormTextField.name(
                    label: L("onboarding.user_info.last_name"),
                    placeholder: L("onboarding.user_info.last_name.placeholder"),
                    text: Binding(
                        get: { viewModel.state.lastName },
                        set: { viewModel.updateLastName($0) }
                    ),
                    textContentType: .familyName
                )
            }
            
            if let error = viewModel.currentError {
                Text(error.localizedDescription)
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Status.error)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            PrimaryButton(
                L("continue"),
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isFormValid,
                action: {
                    Task {
                        let success = await viewModel.handleContinue()
                        if success {
                            await MainActor.run {
                                onComplete()
                            }
                        }
                    }
                }
            )
        }
        .padding(DesignTokens.Spacing.lg)
        .navigationBarBackButtonHidden(true)
    }
}

// Text field style removed - now using shared FormTextField component

