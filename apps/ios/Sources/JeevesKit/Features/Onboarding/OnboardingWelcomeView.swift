/*
 OnboardingWelcomeView.swift
 JeevesKit

 Welcome screen for onboarding with household options
 */

import SwiftUI

/// Welcome view with household creation/joining options
public struct OnboardingWelcomeView: View {
    let onCreateHousehold: () -> Void
    let onJoinHousehold: () -> Void
    let onSignOut: () async -> Void

    public init(
        onCreateHousehold: @escaping () -> Void,
        onJoinHousehold: @escaping () -> Void,
        onSignOut: @escaping () async -> Void
    ) {
        self.onCreateHousehold = onCreateHousehold
        self.onJoinHousehold = onJoinHousehold
        self.onSignOut = onSignOut
    }

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Welcome content
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "house.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.Colors.Primary.base, DesignTokens.Colors.Secondary.base],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )

                VStack(spacing: DesignTokens.Spacing.md) {
                    Text(L("onboarding.welcome.title"))
                        .font(DesignTokens.Typography.Semantic.pageTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)
                        .multilineTextAlignment(.center)

                    Text(L("onboarding.household.subtitle"))
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: DesignTokens.Spacing.md) {
                PrimaryButton(L("onboarding.household.create"), icon: "plus.circle.fill", action: onCreateHousehold)

                SecondaryButton(L("onboarding.household.join"), icon: "person.2", action: onJoinHousehold)

                // Sign out option
                TextButton(L("sign.out")) {
                    Task {
                        await onSignOut()
                    }
                }
                .font(DesignTokens.Typography.Semantic.caption())
                .foregroundColor(DesignTokens.Colors.Text.tertiary)
                .padding(.top, DesignTokens.Spacing.lg)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.Layout.screenEdge)
    }
}

#Preview {
    OnboardingWelcomeView(
        onCreateHousehold: {},
        onJoinHousehold: {},
        onSignOut: {},
    )
}
