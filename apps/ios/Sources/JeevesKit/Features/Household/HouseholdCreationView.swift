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
    @FocusState private var focusedField: Field?
    let onBack: (() -> Void)?
    let onComplete: ((String) -> Void)?

    enum Field: Hashable {
        case householdName
        case description
    }

    public init(viewModel: HouseholdCreationViewModel? = nil, onBack: (() -> Void)? = nil, onComplete: ((String) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
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
                            set: { viewModel?.updateHouseholdName($0) }
                        ),
                        autocorrectionDisabled: true
                    )
                    .focused($focusedField, equals: .householdName)
                    .onSubmit {
                        focusedField = .description
                    }

                    // Description Field (Optional)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Text(L("household.description.label"))
                                .font(DesignTokens.Typography.Semantic.caption())
                                .foregroundColor(DesignTokens.Colors.Text.secondary)

                            Text(L("common.optional"))
                                .font(DesignTokens.Typography.Semantic.caption())
                                .foregroundColor(DesignTokens.Colors.Text.tertiary)
                        }

                        TextField(L("household.description.placeholder"), text: Binding(
                            get: { viewModel?.state.householdDescription ?? "" },
                            set: { viewModel?.updateHouseholdDescription($0) }
                        ), axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Colors.Surface.secondary)
                            .cornerRadius(DesignTokens.BorderRadius.sm)
                            .lineLimit(3 ... 6)
                            .focused($focusedField, equals: .description)
                    }
                }

                // Admin role info
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Colors.Primary.base)

                    Text(L("household.creation.admin_info"))
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)

                    Spacer()
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Surface.secondary)
                .cornerRadius(DesignTokens.BorderRadius.sm)

                if let error = viewModel?.currentError {
                    Text(error.localizedDescription)
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Status.error)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                PrimaryButton(
                    "Create Household",
                    isLoading: viewModel?.isLoading ?? false,
                    isDisabled: !(viewModel?.isFormValid ?? false),
                    action: {
                        Task {
                            if let householdId = await viewModel?.createHousehold() {
                                await MainActor.run {
                                    if let onComplete = onComplete {
                                        onComplete(householdId)
                                    } else {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if viewModel == nil, let factory = viewModelFactory {
                do {
                    viewModel = try factory.makeHouseholdCreationViewModel()
                } catch {
                    Logger.ui.error("Failed to create HouseholdCreationViewModel: \(error)")
                }
            }
            // Auto-focus the household name field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .householdName
            }
        }
    }
}
