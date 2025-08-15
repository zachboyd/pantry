/*
 HouseholdJoinView.swift
 JeevesKit

 View for joining an existing household via invite code
 */

import SwiftUI

/// View for joining an existing household
public struct HouseholdJoinView: View {
    @Environment(\.safeViewModelFactory) private var viewModelFactory
    @State private var viewModel: HouseholdJoinViewModel?

    let showBackButton: Bool
    let onBack: () -> Void
    let onComplete: (String) -> Void

    public init(
        showBackButton: Bool = false,
        onBack: @escaping () -> Void,
        onComplete: @escaping (String) -> Void
    ) {
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onComplete = onComplete
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // Header - matching HouseholdCreationView style
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text(L("household.join.title"))
                        .font(DesignTokens.Typography.Semantic.pageTitle())
                        .multilineTextAlignment(.center)

                    Text(L("household.join.subtitle"))
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignTokens.Spacing.xl)

                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Form
                    FormTextField(
                        label: L("household.invite_code"),
                        placeholder: L("household.invite_code.placeholder"),
                        text: Binding(
                            get: { viewModel?.inviteCode ?? "" },
                            set: { viewModel?.inviteCode = $0 },
                        ),
                        autocapitalization: .never,
                        autocorrectionDisabled: true,
                        validation: { $0.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6 },
                        errorMessage: viewModel?.validationError ?? L("household.invite_code.minimum_length"),
                        font: .monospaced(.body)(),
                        autoFocus: true,
                    )
                    .onSubmit {
                        if viewModel?.isFormValid == true {
                            Task {
                                if let householdId = await viewModel?.joinHousehold() {
                                    onComplete(householdId)
                                }
                            }
                        }
                    }
                }

                // Info section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignTokens.Colors.Status.info)
                        Text(L("household.invite_code.how_to"))
                            .font(DesignTokens.Typography.Semantic.caption())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(L("household.invite_code.step1"))
                        Text(L("household.invite_code.step2"))
                    }
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Text.tertiary)
                    .padding(.leading, DesignTokens.Spacing.lg)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Surface.secondary)
                .cornerRadius(DesignTokens.BorderRadius.Component.card)

                // Join button
                PrimaryButton(
                    L("household.join"),
                    isLoading: viewModel?.isJoining ?? false,
                    isDisabled: !(viewModel?.isFormValid ?? false),
                    action: {
                        Task {
                            if let householdId = await viewModel?.joinHousehold() {
                                onComplete(householdId)
                            }
                        }
                    },
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(!showBackButton)
        .alert(
            L("error"),
            isPresented: Binding(
                get: { viewModel?.joinError != nil },
                set: { _ in viewModel?.clearError() },
            ),
        ) {
            Button(L("ok")) {
                viewModel?.clearError()
            }
        } message: {
            Text(viewModel?.joinError?.localizedDescription ?? L("error.generic"))
        }
        .onAppear {
            if viewModel == nil, let factory = viewModelFactory {
                do {
                    viewModel = try factory.makeHouseholdJoinViewModel()
                } catch {
                    Logger.ui.error("Failed to create HouseholdJoinViewModel: \(error)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HouseholdJoinView(
            onBack: {},
            onComplete: { _ in },
        )
    }
}
