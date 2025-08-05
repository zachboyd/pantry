/*
 AppearanceSettingsView.swift
 PantryKit

 Appearance settings with dark mode support
 */

import SwiftUI

/// Appearance settings view
public struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance_mode") private var appearanceMode: AppearanceMode = .system

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button(action: {
                            appearanceMode = mode
                        }) {
                            HStack {
                                Image(systemName: mode.iconName)
                                    .foregroundColor(mode.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(DesignTokens.Typography.Semantic.body())
                                        .foregroundColor(DesignTokens.Colors.Text.primary)

                                    Text(mode.description)
                                        .font(DesignTokens.Typography.Semantic.caption())
                                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                                }

                                Spacer()

                                if appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignTokens.Colors.Primary.base)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(L("settings.appearance.theme"))
                } footer: {
                    Text(L("settings.appearance.theme.description"))
                }

                Section {
                    // Preview section
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text(L("settings.appearance.preview"))
                            .font(DesignTokens.Typography.Semantic.cardTitle())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        // Mock UI preview
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Circle()
                                    .fill(DesignTokens.Colors.Primary.base)
                                    .frame(width: 20, height: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sample Text")
                                        .font(DesignTokens.Typography.Semantic.body())
                                        .foregroundColor(DesignTokens.Colors.Text.primary)

                                    Text("Secondary text")
                                        .font(DesignTokens.Typography.Semantic.caption())
                                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                                }

                                Spacer()
                            }

                            Button("Sample Button") {
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
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

/// Appearance mode options
public enum AppearanceMode: String, CaseIterable, Codable {
    case light
    case dark
    case system

    @MainActor
    public var displayName: String {
        switch self {
        case .light: return L("settings.appearance.theme.light")
        case .dark: return L("settings.appearance.theme.dark")
        case .system: return L("settings.appearance.theme.system")
        }
    }

    @MainActor
    public var description: String {
        switch self {
        case .light: return L("settings.appearance.theme.light.description")
        case .dark: return L("settings.appearance.theme.dark.description")
        case .system: return L("settings.appearance.theme.system.description")
        }
    }

    public var iconName: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "gear"
        }
    }

    public var color: Color {
        switch self {
        case .light: return .orange
        case .dark: return .indigo
        case .system: return DesignTokens.Colors.Text.secondary
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

#Preview {
    AppearanceSettingsView()
}
