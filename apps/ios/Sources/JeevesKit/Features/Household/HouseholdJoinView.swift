/*
 HouseholdJoinView.swift
 JeevesKit

 View for joining an existing household via invite code
 */

import SwiftUI

/// View for joining an existing household
public struct HouseholdJoinView: View {
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

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

    private var isFormValid: Bool {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6
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
                        text: $inviteCode,
                        autocapitalization: .never,
                        autocorrectionDisabled: true,
                        validation: { $0.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6 },
                        errorMessage: L("household.invite_code.minimum_length"),
                        font: .monospaced(.body)(),
                        autoFocus: true,
                    )
                    .onSubmit {
                        if isFormValid {
                            joinHousehold()
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
                    isLoading: isLoading,
                    isDisabled: !isFormValid,
                    action: joinHousehold,
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(!showBackButton)
        .alert(L("error"), isPresented: $showingAlert) {
            Button(L("ok")) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func joinHousehold() {
        isLoading = true

        Task {
            do {
                // TODO: Implement actual household joining
                try await Task.sleep(for: .seconds(1))

                await MainActor.run {
                    isLoading = false
                    // Return a mock household ID
                    onComplete("household_\(UUID().uuidString)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Invalid invite code or failed to join household. Please try again."
                    showingAlert = true
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
