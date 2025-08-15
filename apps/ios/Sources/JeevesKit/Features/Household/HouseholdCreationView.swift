/*
 HouseholdCreationView.swift
 JeevesKit

 Create a new household with a streamlined onboarding experience
 */

import SwiftUI

/// View for creating a new household with integrated household service
public struct HouseholdCreationView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.safeViewModelFactory) private var viewModelFactory
    @State private var viewModel: HouseholdCreationViewModel?
    let onBack: (() -> Void)?
    let onComplete: ((UUID) -> Void)?
    let showBackButton: Bool

    public init(
        viewModel: HouseholdCreationViewModel? = nil,
        showBackButton: Bool = false,
        onBack: (() -> Void)? = nil,
        onComplete: ((UUID) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onComplete = onComplete
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text(L("household.creation.title"))
                        .font(DesignTokens.Typography.Semantic.pageTitle())
                        .multilineTextAlignment(.center)

                    Text(L("household.creation.subtitle"))
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignTokens.Spacing.xl)

                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Household Name Field
                    FormTextField(
                        label: L("household.name"),
                        placeholder: L("household.name.placeholder"),
                        text: Binding(
                            get: { viewModel?.state.householdName ?? "" },
                            set: { viewModel?.updateHouseholdName($0) },
                        ),
                        autocorrectionDisabled: true,
                        autoFocus: true,
                    )

                    // Description Field (Optional)
                    FormTextField(
                        label: L("household.description.label") + " (" + L("common.optional") + ")",
                        placeholder: L("household.description.placeholder"),
                        text: Binding(
                            get: { viewModel?.state.householdDescription ?? "" },
                            set: { viewModel?.updateHouseholdDescription($0) },
                        ),
                        lineLimit: 3 ... 6,
                    )
                }

                // Admin role info
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Colors.Primary.base)

                    Text(L("household.creation.admin_info"))
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Surface.secondary)
                .cornerRadius(DesignTokens.BorderRadius.sm)

                PrimaryButton(
                    "Create Household",
                    isLoading: viewModel?.isLoading ?? false,
                    isDisabled: !(viewModel?.isFormValid ?? false),
                    action: {
                        Task {
                            if let householdId = await viewModel?.createHousehold() {
                                await MainActor.run {
                                    if let onComplete {
                                        onComplete(householdId)
                                    } else {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    },
                )
                Spacer()

                if let error = viewModel?.currentError {
                    Text(error.localizedDescription)
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Status.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(!showBackButton)
        .onAppear {
            if viewModel == nil, let factory = viewModelFactory {
                do {
                    viewModel = try factory.makeHouseholdCreationViewModel()
                } catch {
                    Logger.ui.error("Failed to create HouseholdCreationViewModel: \(error)")
                }
            }
        }
    }
}
