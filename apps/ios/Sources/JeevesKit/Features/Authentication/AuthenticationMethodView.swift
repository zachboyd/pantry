/*
 AuthenticationMethodView.swift
 JeevesKit

 Initial view for choosing authentication method (social or email/password)
 */

import SwiftUI

/// View for selecting authentication method
public struct AuthenticationMethodView: View {
    private static let logger = Logger.auth

    @State private var isLoadingGoogle = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    let onEmailPasswordSelected: (Bool) -> Void // true for sign up, false for sign in
    let onSocialAuthSuccess: () async -> Void

    @Environment(\.authService) private var authService

    public init(
        onEmailPasswordSelected: @escaping (Bool) -> Void,
        onSocialAuthSuccess: @escaping () async -> Void
    ) {
        self.onEmailPasswordSelected = onEmailPasswordSelected
        self.onSocialAuthSuccess = onSocialAuthSuccess
        Self.logger.info("🔐 AuthenticationMethodView initialized")
    }

    public var body: some View {
        ZStack {
            // Consistent background color
            DesignTokens.Colors.systemBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // App branding and welcome
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                            .padding(.bottom, DesignTokens.Spacing.sm)

                        Text(L("app.name"))
                            .font(DesignTokens.Typography.Semantic.pageTitle())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        Text(L("auth.welcome.subtitle"))
                            .font(DesignTokens.Typography.Semantic.body())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignTokens.Spacing.xxxl)

                    // Social authentication section
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Google Sign In Button
                        SecondaryButton(
                            L("auth.sign_in_google"),
                            customIcon: GoogleIcon(size: 30),
                            isDisabled: isLoadingGoogle,
                            action: signInWithGoogle,
                        )
                        .accessibilityIdentifier("googleSignInButton")

                        // Future: Add more social providers here
                        // Apple Sign In, etc.
                    }
                    .padding(.top, DesignTokens.Spacing.lg)

                    // Divider with "OR"
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text(L("auth.or"))
                            .font(DesignTokens.Typography.Semantic.caption())
                            .foregroundColor(DesignTokens.Colors.Text.tertiary)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)

                    // Email/Password authentication options
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Sign In with Email
                        SecondaryButton(L("auth.signin_with_email")) {
                            onEmailPasswordSelected(false)
                        }
                        .accessibilityIdentifier("emailSignInButton")

                        // Create Account
                        TextButton(L("auth.create_new_account")) {
                            onEmailPasswordSelected(true)
                        }
                        .accessibilityIdentifier("createAccountButton")
                    }

                    // Terms and Privacy
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text(L("auth.agreement_prefix"))
                            .font(DesignTokens.Typography.Semantic.caption())
                            .foregroundColor(DesignTokens.Colors.Text.tertiary)

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Button(L("auth.terms_of_service")) {
                                // TODO: Open terms
                            }
                            .font(DesignTokens.Typography.Semantic.caption())

                            Text(L("auth.and"))
                                .font(DesignTokens.Typography.Semantic.caption())
                                .foregroundColor(DesignTokens.Colors.Text.tertiary)

                            Button(L("auth.privacy_policy")) {
                                // TODO: Open privacy policy
                            }
                            .font(DesignTokens.Typography.Semantic.caption())
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xl)
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xxl)
            }
            .alert(L("error"), isPresented: $showingAlert) {
                Button(L("ok"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func signInWithGoogle() {
        Self.logger.info("🌐 Google sign-in initiated")

        guard let authService else {
            Self.logger.error("❌ AuthService not available")
            alertMessage = L("error.service_unavailable")
            showingAlert = true
            return
        }

        isLoadingGoogle = true

        Task {
            do {
                // Initiate social sign-in
                _ = try await authService.signInWithSocial(provider: "google")
                Self.logger.info("✅ Google sign-in successful")

                // Call success handler
                await onSocialAuthSuccess()

                await MainActor.run {
                    isLoadingGoogle = false
                }
            } catch {
                Self.logger.error("❌ Google sign-in failed: \(error)")
                await MainActor.run {
                    isLoadingGoogle = false

                    if let authError = error as? AuthServiceError {
                        alertMessage = authError.localizedMessage()
                    } else {
                        alertMessage = L("auth.error.social_signin_failed")
                    }

                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationMethodView(
        onEmailPasswordSelected: { _ in },
        onSocialAuthSuccess: {},
    )
}
