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

    @State private var showSignUp = false
    @State private var email = ""

    public var body: some View {
        NavigationStack {
            ZStack {
                if showSignUp {
                    SignUpView(
                        email: $email,
                        onSignInTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSignUp = false
                            }
                        },
                        onSignUpSuccess: {
                            await handleAuthenticationSuccess()
                        },
                    )
                    .transition(.opacity)
                } else {
                    SignInView(
                        email: $email,
                        onSignUpTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSignUp = true
                            }
                        },
                        onSignInSuccess: {
                            await handleAuthenticationSuccess()
                        },
                    )
                    .transition(.opacity)
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
