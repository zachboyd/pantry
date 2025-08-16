import SwiftUI

/// A reusable avatar component that displays user profile image or initials
public struct AvatarView: View {
    // MARK: - Size Definition

    public enum Size {
        case small
        case medium
        case large
        case extraLarge

        var value: CGFloat {
            switch self {
            case .small: 32
            case .medium: 44
            case .large: 64
            case .extraLarge: 80
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: 14
            case .medium: 18
            case .large: 24
            case .extraLarge: 32
            }
        }
    }

    // MARK: - Properties

    private let user: User?
    private let size: Size
    private let onTap: (() -> Void)?

    @State private var isHovered = false

    // MARK: - Computed Properties

    private var displayName: String {
        user?.name ?? "Unknown"
    }

    private var initials: String {
        // Use the User model's built-in initials property
        user?.initials ?? "?"
    }

    private var avatarUrl: String? {
        user?.avatarUrl
    }

    private var backgroundColor: Color {
        // Generate a consistent color based on the user ID
        if let userId = user?.id {
            let hash = userId.hashValue
            let hue = Double(abs(hash) % 360) / 360.0
            return Color(hue: hue, saturation: 0.5, brightness: 0.8)
        } else {
            return DesignTokens.Colors.Surface.secondary
        }
    }

    // MARK: - Initializers

    public init(
        user: User?,
        size: Size = .medium,
        onTap: (() -> Void)? = nil
    ) {
        self.user = user
        self.size = size
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        let avatarContent = Group {
            if let user, user.isAi {
                // Show AI avatar for AI users using the dedicated component
                AIAvatarView(customSize: size.value)
            } else if let avatarUrl,
                      !avatarUrl.isEmpty,
                      let url = URL(string: avatarUrl)
            {
                // Show async image
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: size.value, height: size.value)

                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.value, height: size.value)
                            .clipShape(Circle())

                    case .failure:
                        // Fall back to initials on failure
                        initialsView

                    @unknown default:
                        initialsView
                    }
                }
            } else if user != nil {
                // Show initials
                initialsView
            } else {
                // Show fallback for no user
                fallbackView
            }
        }
        .frame(width: size.value, height: size.value)
        .contentShape(Circle())

        if let onTap {
            Button(action: onTap) {
                avatarContent
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("User profile: \(displayName)")
            .accessibilityHint("Tap to view profile")
            .accessibilityAddTraits(.isButton)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        } else {
            avatarContent
                .accessibilityLabel("User avatar: \(displayName)")
                .accessibilityAddTraits(.isImage)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            Text(initials)
                .font(.system(size: size.fontSize, weight: .medium))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: size.value * 0.9))
            .foregroundColor(DesignTokens.Colors.Text.secondary)
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Previews

#Preview("Avatar Sizes") {
    HStack(spacing: 20) {
        ForEach([AvatarView.Size.small, .medium, .large, .extraLarge], id: \.self) { size in
            VStack {
                AvatarView(
                    user: User(
                        id: LowercaseUUID(),
                        email: "test@example.com",
                        name: "John Doe",
                        createdAt: Date(),
                    ),
                    size: size,
                )

                Text(String(describing: size))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding()
}

#Preview("Avatar States") {
    VStack(spacing: 20) {
        // With initials
        AvatarView(
            user: User(
                id: LowercaseUUID(),
                email: "test@example.com",
                name: "Jane Smith",
                createdAt: Date(),
            ),
        )

        // With single name
        AvatarView(
            user: User(
                id: LowercaseUUID(),
                email: "test@example.com",
                name: "Madonna",
                createdAt: Date(),
            ),
        )

        // No user
        AvatarView(user: nil)

        // With tap action
        AvatarView(
            user: User(
                id: LowercaseUUID(),
                email: "test@example.com",
                name: "Tap Me",
                createdAt: Date(),
            ),
            onTap: {
                print("Avatar tapped!")
            },
        )
    }
    .padding()
}
