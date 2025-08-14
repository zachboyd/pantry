import SwiftUI

/// A reusable view component for displaying AI avatars throughout the app.
/// Provides a consistent visual representation of AI entities with customizable size and interaction.
public struct AIAvatarView: View {
    /// The size of the avatar circle
    let size: CGFloat

    /// Whether the avatar should be tappable
    let isInteractive: Bool

    /// Optional action to perform when tapped
    let onTap: (() -> Void)?

    /// Hover state for iPadOS
    @State private var isHovered = false

    /// Standard sizes for common use cases
    public enum Size {
        case small // Uses design token
        case medium // Uses design token (default for chat)
        case large // Uses design token
        case extraLarge // Uses design token

        var value: CGFloat {
            switch self {
            case .small: DesignTokens.ComponentSize.Avatar.small
            case .medium: DesignTokens.ComponentSize.Avatar.medium
            case .large: DesignTokens.ComponentSize.Avatar.large
            case .extraLarge: DesignTokens.ComponentSize.Avatar.extraLarge
            }
        }
    }

    public init(
        size: Size = .medium,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.size = size.value
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    public init(
        customSize: CGFloat,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        size = customSize
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    public var body: some View {
        if isInteractive, onTap != nil {
            Button(action: { onTap?() }) {
                avatarContent
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(L("accessibility.avatar.ai"))
            .accessibilityAddTraits(.isButton)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        } else {
            avatarContent
        }
    }

    private var avatarContent: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.AI.gradient)

            Image(systemName: "sparkles")
                .font(.system(size: iconSize))
                .foregroundColor(DesignTokens.Colors.AI.icon)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, options: .repeating, isActive: isHovered)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .accessibilityLabel(L("accessibility.avatar.ai"))
        .accessibilityAddTraits(.isImage)
    }

    private var iconSize: CGFloat {
        // Scale icon size proportionally to avatar size
        size * 0.45
    }
}

// MARK: - Previews

#Preview("AI Avatar Sizes") {
    HStack(spacing: 20) {
        VStack {
            AIAvatarView(size: .small)
            Text("Small")
                .font(.caption)
        }

        VStack {
            AIAvatarView(size: .medium)
            Text("Medium")
                .font(.caption)
        }

        VStack {
            AIAvatarView(size: .large)
            Text("Large")
                .font(.caption)
        }

        VStack {
            AIAvatarView(size: .extraLarge)
            Text("Extra Large")
                .font(.caption)
        }
    }
    .padding()
}

#Preview("Interactive AI Avatar") {
    AIAvatarView(
        size: .medium,
        isInteractive: true,
        onTap: {
            print("AI Avatar tapped")
        },
    )
    .padding()
}
