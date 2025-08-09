/*
 HouseholdJoinView.swift
 PantryKit

 View for joining an existing household via invite code
 */

import SwiftUI

/// View for joining an existing household
public struct HouseholdJoinView: View {
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isInviteCodeFocused: Bool

    let onBack: () -> Void
    let onComplete: (String) -> Void

    public init(
        onBack: @escaping () -> Void,
        onComplete: @escaping (String) -> Void
    ) {
        self.onBack = onBack
        self.onComplete = onComplete
    }

    private var isFormValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    Spacer()
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.Secondary.base)

                    Text(L("household.join"))
                        .font(DesignTokens.Typography.Semantic.pageTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)

                    Text(L("household.join.subtitle"))
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Form
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(L("household.invite_code"))
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Text.secondary)

                TextField(L("household.invite_code.placeholder"), text: $inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.monospaced(.body)())
                    .focused($isInviteCodeFocused)
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

            Spacer()

            // Join button
            Button(action: joinHousehold) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(L("household.join"))
                        .font(DesignTokens.Typography.Semantic.button())
                }
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.ComponentSize.Button.large)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || isLoading)
            }
            .padding(DesignTokens.Spacing.Layout.screenEdge)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert(L("error"), isPresented: $showingAlert) {
            Button(L("ok")) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Auto-focus the invite code field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInviteCodeFocused = true
            }
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
    HouseholdJoinView(
        onBack: {},
        onComplete: { _ in }
    )
}
