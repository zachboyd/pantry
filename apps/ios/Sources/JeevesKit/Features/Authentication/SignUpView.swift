/*
 SignUpView.swift
 JeevesKit

 Sign up form with email and password
 */

import SwiftUI

/// Sign up view with form validation
public struct SignUpView: View {
    private static let logger = Logger.auth

    @Binding var email: String
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    enum Field: Hashable {
        case email
        case password
        case confirmPassword
    }

    @FocusState private var focusedField: Field?

    @Environment(\.authService) private var authService

    let onSignInTap: () -> Void
    let onSignUpSuccess: () async -> Void

    public init(email: Binding<String>, onSignInTap: @escaping () -> Void, onSignUpSuccess: @escaping () async -> Void) {
        _email = email
        self.onSignInTap = onSignInTap
        self.onSignUpSuccess = onSignUpSuccess
        Self.logger.info("📝 SignUpView initialized")
    }

    private var isFormValid: Bool {
        return !email.isEmpty &&
            email.contains("@") &&
            password.count >= PasswordConstants.minimumLength &&
            password == confirmPassword
    }

    private var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }

    public var body: some View {
        ZStack {
            // Consistent background color
            DesignTokens.Colors.systemBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header with icon
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                            .padding(.bottom, DesignTokens.Spacing.sm)

                        Text(L("auth.button.create"))
                            .font(DesignTokens.Typography.Semantic.sectionHeader())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        Text(L("auth.signup.subtitle"))
                            .font(DesignTokens.Typography.Semantic.body())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                    }
                    .padding(.top, DesignTokens.Spacing.xxl)
                    .padding(.bottom, DesignTokens.Spacing.xl)

                    // Form
                    VStack(spacing: DesignTokens.Spacing.md) {
                        FormTextField.email(text: $email)
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }

                        VStack(spacing: DesignTokens.Spacing.xs) {
                            FormTextField.password(
                                placeholder: PasswordConstants.placeholder,
                                text: $password,
                                isNewPassword: true,
                                validation: { $0.count >= PasswordConstants.minimumLength },
                                errorMessage: PasswordConstants.tooShortError
                            )
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }

                            // Password strength meter
                            // PasswordStrengthMeter(password: password)

                            // Password requirements
                            // PasswordRequirementsView(password: password)
                        }

                        FormTextField.password(
                            label: L("auth.confirm_password"),
                            placeholder: PasswordConstants.confirmPlaceholder,
                            text: $confirmPassword,
                            isNewPassword: true,
                            validation: { $0 == password && !$0.isEmpty },
                            errorMessage: PasswordConstants.mismatchError
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            // Dismiss keyboard and trigger sign up if form is valid
                            focusedField = nil
                            if isFormValid {
                                signUp()
                            }
                        }
                    }

                    // Sign up button
                    PrimaryButton(L("auth.button.create"), isLoading: isLoading, isDisabled: !isFormValid, action: signUp)

                    // Sign in link
                    HStack {
                        Text(L("auth.has_account"))
                            .font(DesignTokens.Typography.Semantic.body())
                            .foregroundColor(DesignTokens.Colors.Text.secondary)

                        TextButton(L("auth.button.signin"), action: onSignInTap)
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
                Self.logger.info("📱 SignUpView appeared")
            }
        }
    }

    private func signUp() {
        Self.logger.info("🚀 Sign up button tapped")
        Self.logger.info("📧 Email: \(email)")
        Self.logger.info("🔑 Password length: \(password.count)")

        guard let authService = authService else {
            Self.logger.error("❌ Cannot sign up - authService not available")
            alertMessage = "Unable to sign up. Please try again."
            showingAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                Self.logger.info("📡 Calling authService.signUp")
                let userId = try await authService.signUp(email: email, password: password)
                Self.logger.info("✅ Sign up successful! User ID: \(userId)")

                // Call the success handler
                await onSignUpSuccess()

                await MainActor.run {
                    isLoading = false
                }
            } catch {
                Self.logger.error("❌ Sign up failed: \(error)")
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
    SignUpView(email: $email, onSignInTap: {}, onSignUpSuccess: {})
}
