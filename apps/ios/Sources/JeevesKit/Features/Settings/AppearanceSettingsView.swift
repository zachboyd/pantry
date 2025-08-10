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
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedTheme: ThemePreference
    @State private var originalTheme: ThemePreference

    public init() {
        // Initialize with the saved theme from ThemeManager, fallback to system
        let savedTheme = ThemeManager.shared.userSavedTheme ?? .system
        _selectedTheme = State(initialValue: savedTheme)
        _originalTheme = State(initialValue: savedTheme)
    }

    public var body: some View {
        let osColorScheme: ColorScheme = systemColorScheme
        let selectedColorScheme: ColorScheme = selectedTheme == .light ? .light : .dark

        NavigationStack {
            List {
                Section {
                    ForEach(ThemePreference.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.displayName)
                                    .foregroundColor(DesignTokens.Colors.Text.primary)

                                Text(themeDescription(for: theme))
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
                            // Apply theme temporarily for preview
                            themeManager.updateTheme(theme)
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
            .onDisappear {
                // If the theme wasn't saved, revert to original theme
                if themeManager.currentTheme != originalTheme {
                    themeManager.updateTheme(originalTheme)
                }
            }
        }
        .preferredColorScheme(selectedTheme == .system ? osColorScheme : selectedColorScheme)
    }

    private func themeDescription(for theme: ThemePreference) -> String {
        switch theme {
        case .system:
            return L("settings.appearance.theme.system.description")
        case .light:
            return L("settings.appearance.theme.light.description")
        case .dark:
            return L("settings.appearance.theme.dark.description")
        }
    }

    private func saveAppearanceSettings() {
        // Save theme to persistent storage
        themeManager.setUserSavedTheme(selectedTheme)
        originalTheme = selectedTheme
        dismiss()
    }
}

#Preview {
    AppearanceSettingsView()
}
