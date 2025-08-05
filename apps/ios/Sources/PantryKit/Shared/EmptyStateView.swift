/*
 EmptyStateView.swift
 PantryKit

 Reusable empty state component for displaying helpful messages
 when there's no content to show
 */

import SwiftUI

/// Action for empty state
public struct EmptyStateAction: Sendable {
    let title: String
    let style: EmptyStateActionStyle
    let action: @Sendable () -> Void

    public init(
        title: String,
        style: EmptyStateActionStyle = .primary,
        action: @escaping @Sendable () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }
}

/// Style for empty state action buttons
public enum EmptyStateActionStyle: Sendable {
    case primary
    case secondary
}

/// Configuration for empty state display
public struct EmptyStateConfig: Sendable {
    let icon: String
    let title: String
    let subtitle: String?
    let actions: [EmptyStateAction]

    // Legacy single action support
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (@Sendable () -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle

        if let actionTitle = actionTitle, let action = action {
            actions = [EmptyStateAction(title: actionTitle, style: .primary, action: action)]
        } else {
            actions = []
        }
    }

    // New multi-action support
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actions: [EmptyStateAction] = []
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }
}

/// Reusable empty state view component
public struct EmptyStateView: View {
    let config: EmptyStateConfig

    // Check if this is an error state
    private var isErrorState: Bool {
        config.icon == "exclamationmark.triangle"
    }

    public init(config: EmptyStateConfig) {
        self.config = config
    }

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Icon
            Image(systemName: config.icon)
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                // Title
                Text(config.title)
                    .font(DesignTokens.Typography.Semantic.sectionHeader())
                    .foregroundColor(DesignTokens.Colors.Text.primary)
                    .multilineTextAlignment(.center)

                // Subtitle
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Action buttons
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(config.actions.indices, id: \.self) { index in
                    let action = config.actions[index]
                    switch action.style {
                    case .primary:
                        PrimaryButton(action.title, action: action.action)
                            .frame(maxWidth: 280)
                    case .secondary:
                        SecondaryButton(action.title, action: action.action)
                            .frame(maxWidth: 280)
                    }
                }
            }

            // Debug button for error states
            #if DEBUG
                if isErrorState {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Divider()
                            .padding(.vertical, DesignTokens.Spacing.md)

                        Text("Debug Options")
                            .font(DesignTokens.Typography.Semantic.caption())
                            .foregroundColor(DesignTokens.Colors.Text.tertiary)

                        Button {
                            // Clear all auth data
                            KeychainHelper.clearAllAuthData()

                            // Force app to restart/refresh
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first
                            {
                                window.rootViewController = UIHostingController(
                                    rootView: AppRootView()
                                        .withAppState()
                                )
                            }
                        } label: {
                            Label("Clear Auth Data", systemImage: "trash")
                                .font(DesignTokens.Typography.Semantic.caption())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(DesignTokens.Colors.Status.error)
                    }
                    .padding(.top, DesignTokens.Spacing.lg)
                }
            #endif
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.Surface.primary)
    }
}

// MARK: - Common Empty State Configurations

public extension EmptyStateConfig {
    /// Loading state
    @MainActor
    static var loading: EmptyStateConfig {
        EmptyStateConfig(
            icon: "clock",
            title: L("app.loading"),
            subtitle: L("loading.message")
        )
    }

    /// Error state
    @MainActor
    static func error(_ message: String) -> EmptyStateConfig {
        return EmptyStateConfig(
            icon: "exclamationmark.triangle",
            title: L("error.generic_title"),
            subtitle: message,
            actionTitle: L("error.try_again"),
            action: nil
        )
    }
    
    // Note: Tab-specific empty states have been moved to AppSections.emptyStateConfig(for:)
    // Use AppSections.emptyStateConfig(for: .pantry) instead of .emptyPantry
}

#Preview("Empty State") {
    EmptyStateView(config: AppSections.emptyStateConfig(for: .pantry))
}

#Preview("Error State") {
    EmptyStateView(config: .error("Something went wrong"))
}

#Preview("Loading State") {
    EmptyStateView(config: .loading)
}
