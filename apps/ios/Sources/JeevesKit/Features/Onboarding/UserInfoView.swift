/*
 UserInfoView.swift
 JeevesKit

 User information collection view for onboarding
 */

import SwiftUI

/// View for collecting user's first and last name during onboarding
public struct UserInfoView: View {
    let viewModel: UserInfoViewModel
    let onComplete: () -> Void

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case firstName
        case lastName
    }

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
                        set: { viewModel.updateFirstName($0) },
                    ),
                    textContentType: .givenName,
                )
                .focused($focusedField, equals: .firstName)
                .onSubmit {
                    focusedField = .lastName
                }

                FormTextField.name(
                    label: L("onboarding.user_info.last_name"),
                    placeholder: L("onboarding.user_info.last_name.placeholder"),
                    text: Binding(
                        get: { viewModel.state.lastName },
                        set: { viewModel.updateLastName($0) },
                    ),
                    textContentType: .familyName,
                )
                .focused($focusedField, equals: .lastName)
                .onSubmit {
                    if viewModel.isFormValid {
                        Task {
                            let success = await viewModel.handleContinue()
                            if success {
                                await MainActor.run {
                                    onComplete()
                                }
                            }
                        }
                    }
                }
            }

            if let error = viewModel.currentError {
                Text(error.localizedDescription)
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Status.error)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                L("continue"),
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isFormValid,
            ) {
                Task {
                    let success = await viewModel.handleContinue()
                    if success {
                        await MainActor.run {
                            onComplete()
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Auto-focus the first name field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .firstName
            }
        }
    }
}
