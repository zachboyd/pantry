/*
 AppearanceSettingsView.swift
 JeevesKit

 Appearance settings with dark mode support
 */

import SwiftUI

/// Appearance settings view
public struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    @State private var selectedTheme: ThemePreference = .system
    @State private var originalTheme: ThemePreference = .system
    @State private var hasInitialized = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ThemePreference.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.displayName)
                                    .foregroundColor(DesignTokens.Colors.Text.primary)

                                Text(theme.description)
                                    .font(DesignTokens.Typography.Semantic.caption())
                                    .foregroundColor(DesignTokens.Colors.Text.secondary)
                            }

                            Spacer()

                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignTokens.Colors.Primary.base)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                            // Update theme in manager for preview
                            themeManager.updateTheme(theme)
                            // Always apply to UIKit for immediate preview
                            // This ensures both modal and background app show the same theme
                            themeManager.applyThemeToWindow()
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(L("settings.appearance.theme")).textCase(.uppercase).font(.caption).foregroundColor(.secondary)
                } footer: {
                    Text(L("settings.appearance.theme.description"))
                }

                Section {
                    // Preview section showing how the theme looks
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text(L("settings.appearance.preview"))
                            .font(DesignTokens.Typography.Semantic.cardTitle())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        // Mock UI preview that updates with theme changes
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Circle()
                                    .fill(DesignTokens.Colors.Primary.base)
                                    .frame(width: 20, height: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("settings.appearance.preview.sample_text"))
                                        .font(DesignTokens.Typography.Semantic.body())
                                        .foregroundColor(DesignTokens.Colors.Text.primary)

                                    Text(L("settings.appearance.preview.secondary_text"))
                                        .font(DesignTokens.Typography.Semantic.caption())
                                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                                }

                                Spacer()
                            }

                            Button(L("settings.appearance.preview.sample_button")) {
                                // No action needed for preview
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.Surface.secondary)
                        .cornerRadius(DesignTokens.BorderRadius.Component.card)
                    }
                } header: {
                    Text(L("settings.appearance.preview"))
                }
            }
            .navigationTitle(L("settings.appearance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) {
                        saveAppearanceSettings()
                    }
                    .disabled(selectedTheme == originalTheme)
                }
            }
            .onAppear {
                // Initialize themes from the manager on first appear
                if !hasInitialized {
                    let savedTheme = themeManager.userSavedTheme ?? ThemePreference.system
                    selectedTheme = savedTheme
                    originalTheme = savedTheme
                    hasInitialized = true
                }
            }
            .onDisappear {
                // If user didn't save, restore the original theme
                if selectedTheme != originalTheme {
                    themeManager.updateTheme(originalTheme)
                    // Always apply the original theme to UIKit when cancelling
                    themeManager.applyThemeToWindow()
                }
            }
        }
    }

    private func saveAppearanceSettings() {
        // Save theme to persistent storage and apply to UIKit
        themeManager.setUserSavedTheme(selectedTheme)
        themeManager.applyThemeToWindow() // Ensure UIKit is updated when saving
        originalTheme = selectedTheme
        dismiss()
    }
}

#Preview {
    AppearanceSettingsView()
}
