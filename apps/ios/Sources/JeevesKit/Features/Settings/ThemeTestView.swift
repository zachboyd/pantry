/*
 ThemeTestView.swift
 JeevesKit

 Test view to verify theme system integration
 This can be used during development to test theme switching
 */

import SwiftUI

/// Simple test view to verify theme switching works correctly
struct ThemeTestView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Text("Theme Test")
                    .font(DesignTokens.Typography.Semantic.pageTitle())
                    .foregroundColor(DesignTokens.Colors.Text.primary)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Current Theme: \(themeManager.currentTheme.rawValue)")
                        .font(DesignTokens.Typography.Semantic.cardTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)

                    Text("Color Scheme: \(themeManager.colorScheme?.description ?? "system")")
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)

                    Text("This text should change color based on the selected theme")
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.tertiary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Surface.secondary)
                .cornerRadius(DesignTokens.BorderRadius.Component.card)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(ThemePreference.allCases, id: \.self) { theme in
                        Button(action: {
                            themeManager.setUserSavedTheme(theme)
                        }) {
                            HStack {
                                Text(theme.displayName)
                                    .font(DesignTokens.Typography.Semantic.button())

                                Spacer()

                                if themeManager.currentTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignTokens.Colors.Primary.base)
                                }
                            }
                            .padding(DesignTokens.Spacing.md)
                            .background(
                                themeManager.currentTheme == theme ?
                                    DesignTokens.Colors.Primary.light.opacity(0.2) :
                                    DesignTokens.Colors.Surface.primary
                            )
                            .cornerRadius(DesignTokens.BorderRadius.Component.button)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
            .navigationTitle("Theme Test")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignTokens.Colors.systemBackground())
        }
    }
}

// Extension to make ColorScheme description readable
private extension ColorScheme {
    var description: String {
        switch self {
        case .light: return "light"
        case .dark: return "dark"
        @unknown default: return "unknown"
        }
    }
}

#Preview {
    ThemeTestView()
        .withAppState()
}
