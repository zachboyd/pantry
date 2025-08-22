/*
 AuthenticationContainerView.swift
 JeevesKit

 Main authentication flow container supporting login and signup
 */

import SwiftUI

/// Container view for authentication flow
public struct AuthenticationContainerView: View {
    private static let logger = Logger.auth
    @Environment(\.appState) private var appState

    public init() {
        Self.logger.info("🔐 AuthenticationContainerView initialized")
    }

    enum AuthMode {
        case method // Choose authentication method
        case passwordSignIn
        case passwordSignUp
    }

    @State private var authMode: AuthMode = .method
    @State private var email = ""

    public var body: some View {
        NavigationStack {
            ZStack {
                switch authMode {
                case .method:
                    AuthenticationMethodView(
                        onEmailPasswordSelected: { isSignUp in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                authMode = isSignUp ? .passwordSignUp : .passwordSignIn
                            }
                        },
                        onSocialAuthSuccess: {
                            await handleAuthenticationSuccess()
                        },
                    )
                    .transition(.opacity)

                case .passwordSignIn:
                    PasswordSignInView(
                        email: $email,
                        onSignUpTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                authMode = .passwordSignUp
                            }
                        },
                        onSignInSuccess: {
                            await handleAuthenticationSuccess()
                        },
                    )
                    .transition(.opacity)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    authMode = .method
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }

                case .passwordSignUp:
                    PasswordSignUpView(
                        email: $email,
                        onSignInTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                authMode = .passwordSignIn
                            }
                        },
                        onSignUpSuccess: {
                            await handleAuthenticationSuccess()
                        },
                    )
                    .transition(.opacity)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    authMode = .method
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleAuthenticationSuccess() async {
        if let appState {
            Self.logger.info("📲 Notifying AppState of successful authentication")
            await appState.handleAuthenticated()
        } else {
            Self.logger.error("❌ AppState not available to notify")
        }
    }
}
