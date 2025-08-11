/*
 PrimaryButton.swift
 JeevesKit

 Reusable button components with consistent styling across the app

 Architecture:
 - BaseButton: Core button implementation with common functionality
 - PrimaryButton: Prominent button style (filled background)
 - SecondaryButton: Bordered button style
 - TextButton: Text-only button for supplementary actions
 */

import SwiftUI

// MARK: - Button Style Configuration

/// Defines the visual style variants for buttons
public enum ButtonStyleVariant {
    case primary
    case secondary

    var backgroundColor: Color {
        switch self {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color(UIColor.secondarySystemBackground)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary:
            return .white
        case .secondary:
            return .accentColor
        }
    }

    var strokeColor: Color? {
        switch self {
        case .primary:
            return nil
        case .secondary:
            return .accentColor
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .primary:
            return 0
        case .secondary:
            return 1.0
        }
    }
}

// MARK: - Base Button Component

/// Base button component that provides common functionality for all button styles
struct BaseButton: View {
    // MARK: - Constants

    private enum Constants {
        static let height: CGFloat = 54
        static let cornerRadius: CGFloat = height / 2
        static let contentSpacing: CGFloat = 8
        static let disabledOpacity: CGFloat = 0.6
        static let loadingScaleFactor: CGFloat = 0.8
    }

    // MARK: - Properties

    private let title: String
    private let icon: String?
    private let style: ButtonStyleVariant
    private let isLoading: Bool
    private let isDisabled: Bool
    private let action: () -> Void

    // MARK: - Initialization

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyleVariant,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            ZStack {
                backgroundLayer
                contentLayer
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? Constants.disabledOpacity : 1.0)
    }

    // MARK: - View Components

    @ViewBuilder
    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(style.backgroundColor)
            .frame(height: Constants.height)

        if let strokeColor = style.strokeColor {
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(strokeColor, lineWidth: style.strokeWidth)
                .frame(height: Constants.height)
        }
    }

    private var contentLayer: some View {
        HStack(spacing: Constants.contentSpacing) {
            if isLoading && style == .primary {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                    .scaleEffect(Constants.loadingScaleFactor)
            } else if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(style.foregroundColor)
            }

            Text(displayTitle)
                .font(.system(.callout, design: .default, weight: .semibold))
                .foregroundColor(style.foregroundColor)
        }
    }

    private var displayTitle: String {
        isLoading && icon == nil && style == .primary ? "\(title)..." : title
    }
}

// MARK: - Public Button Components

/// A primary button component with consistent styling and loading state support
public struct PrimaryButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    private let isLoading: Bool
    private let isDisabled: Bool

    /// Creates a primary button with the specified configuration
    /// - Parameters:
    ///   - title: The button's title text
    ///   - icon: Optional SF Symbol name to display
    ///   - isLoading: Whether to show a loading indicator
    ///   - isDisabled: Whether the button should be disabled
    ///   - action: The action to perform when tapped
    public init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        BaseButton(
            title,
            icon: icon,
            style: .primary,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        )
    }
}

/// A secondary button component with bordered style
public struct SecondaryButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    private let isDisabled: Bool

    /// Creates a secondary button with the specified configuration
    /// - Parameters:
    ///   - title: The button's title text
    ///   - icon: Optional SF Symbol name to display
    ///   - isDisabled: Whether the button should be disabled
    ///   - action: The action to perform when tapped
    public init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        BaseButton(
            title,
            icon: icon,
            style: .secondary,
            isDisabled: isDisabled,
            action: action
        )
    }
}

/// A text-only button component for secondary actions
public struct TextButton: View {
    private let title: String
    private let action: () -> Void

    /// Creates a text button with the specified configuration
    /// - Parameters:
    ///   - title: The button's title text
    ///   - action: The action to perform when tapped
    public init(
        _ title: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundColor(DesignTokens.Colors.Text.link)
    }
}

#Preview("Button Components") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Primary buttons
        Text("Primary Buttons")
            .font(DesignTokens.Typography.Semantic.sectionHeader())

        PrimaryButton("Sign In") {
            print("Sign in tapped")
        }

        PrimaryButton("Create Account", icon: "plus.circle.fill") {
            print("Create account tapped")
        }

        PrimaryButton("Loading", isLoading: true) {
            print("Loading button tapped")
        }

        PrimaryButton("Disabled", isDisabled: true) {
            print("Disabled button tapped")
        }

        // Secondary buttons
        Text("Secondary Buttons")
            .font(DesignTokens.Typography.Semantic.sectionHeader())
            .padding(.top)

        SecondaryButton("Join Household", icon: "person.2") {
            print("Join household tapped")
        }

        SecondaryButton("Secondary Action") {
            print("Secondary action tapped")
        }

        // Text button
        Text("Text Button")
            .font(DesignTokens.Typography.Semantic.sectionHeader())
            .padding(.top)

        TextButton("Sign Up") {
            print("Sign up tapped")
        }
    }
    .padding()
}
