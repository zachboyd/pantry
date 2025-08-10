/*
 SignInView.swift
 JeevesKit

 Sign in form with email and password
 */

import SwiftUI

/// Sign in view with form validation
public struct SignInView: View {
    private static let logger = Logger.auth

    @Binding var email: String
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    enum Field: Hashable {
        case email
        case password
    }

    @FocusState private var focusedField: Field?

    @Environment(\.authService) private var authService

    let onSignUpTap: () -> Void
    let onSignInSuccess: () async -> Void

    public init(email: Binding<String>, onSignUpTap: @escaping () -> Void, onSignInSuccess: @escaping () async -> Void) {
        _email = email
        self.onSignUpTap = onSignUpTap
        self.onSignInSuccess = onSignInSuccess
        Self.logger.info("🔑 SignInView initialized")
    }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    public var body: some View {
        ZStack {
            // Consistent background color
            DesignTokens.Colors.systemBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header with greeting
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                            .padding(.bottom, DesignTokens.Spacing.sm)

                        Text(L("auth.welcome_back"))
                            .font(DesignTokens.Typography.Semantic.sectionHeader())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        Text(L("auth.signin.subtitle"))
                            .font(DesignTokens.Typography.Semantic.body())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                    }
                    .padding(.top, DesignTokens.Spacing.xxl)
                    .padding(.bottom, DesignTokens.Spacing.xl)

                    // Form
                    VStack(spacing: DesignTokens.Spacing.md) {
                        FormTextField.email(
                            text: $email,
                            accessibilityIdentifier: AccessibilityUtilities.Identifier.emailField
                        )
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .password
                        }

                        FormTextField.password(
                            text: $password,
                            accessibilityIdentifier: AccessibilityUtilities.Identifier.passwordField,
                            validation: { $0.count >= 6 },
                            errorMessage: L("auth.password.too_short")
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            // Dismiss keyboard and trigger sign in if form is valid
                            focusedField = nil
                            if isFormValid {
                                signIn()
                            }
                        }
                    }

                    // Sign in button
                    PrimaryButton(L("auth.button.signin"), isLoading: isLoading, isDisabled: !isFormValid, action: signIn)
                        .accessibilityIdentifier(AccessibilityUtilities.Identifier.signInButton)
                        .accessibilityLabel("Sign in")
                        .accessibilityHint("Double tap to sign in with your email and password")

                    // Sign up link
                    HStack {
                        Text(L("auth.no_account"))
                            .font(DesignTokens.Typography.Semantic.body())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)

                        TextButton(L("auth.button.signup"), action: onSignUpTap)
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .alert(L("error"), isPresented: $showingAlert) {
                Button(L("ok"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Self.logger.info("📱 SignInView appeared")
            }
        }
    }

    private func signIn() {
        Self.logger.info("🚀 Sign in button tapped")
        Self.logger.info("📧 Email: \(email)")

        guard let authService = authService else {
            Self.logger.error("❌ Cannot sign in - authService not available")
            alertMessage = "Unable to sign in. Please try again."
            showingAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                Self.logger.info("📡 Calling authService.signIn")
                let userId = try await authService.signIn(email: email, password: password)
                Self.logger.info("✅ Sign in successful! User ID: \(userId)")

                // Call the success handler
                await onSignInSuccess()

                await MainActor.run {
                    isLoading = false
                }
            } catch {
                Self.logger.error("❌ Sign in failed: \(error)")
                await MainActor.run {
                    isLoading = false

                    // Use localized message for AuthServiceError
                    if let authError = error as? AuthServiceError {
                        alertMessage = authError.localizedMessage()
                    } else {
                        // Fallback for non-AuthServiceError errors
                        alertMessage = error.localizedDescription
                    }

                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    SignInView(email: $email, onSignUpTap: {}, onSignInSuccess: {})
}
