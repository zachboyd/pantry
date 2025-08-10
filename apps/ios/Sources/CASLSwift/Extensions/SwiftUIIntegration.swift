import Combine
import SwiftUI

// MARK: - Environment Key for Ability

/// Environment key to inject ability into the SwiftUI environment
public struct AbilityEnvironmentKey: EnvironmentKey {
    public static let defaultValue: PureAbility? = nil
}

/// Environment values extension
public extension EnvironmentValues {
    var ability: PureAbility? {
        get { self[AbilityEnvironmentKey.self] }
        set { self[AbilityEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifiers

/// View modifier that conditionally shows content based on permissions
public struct CanViewModifier: ViewModifier {
    let action: String
    let subject: String
    let ability: PureAbility?

    @Environment(\.ability) private var environmentAbility

    public func body(content: Content) -> some View {
        let currentAbility = ability ?? environmentAbility

        if let currentAbility = currentAbility,
           currentAbility.canSync(action, subject) ?? false
        {
            content
        }
    }
}

/// View modifier to inject ability into environment
public struct AbilityModifier: ViewModifier {
    let ability: PureAbility

    public func body(content: Content) -> some View {
        content
            .environment(\.ability, ability)
    }
}

/// View modifier that shows alternative content when permission is denied
public struct PermissionBasedContentModifier<Alternative: View>: ViewModifier {
    let action: String
    let subject: String
    let ability: PureAbility?
    let alternative: Alternative

    @Environment(\.ability) private var environmentAbility

    public func body(content: Content) -> some View {
        let currentAbility = ability ?? environmentAbility

        if let currentAbility = currentAbility,
           currentAbility.canSync(action, subject) ?? false
        {
            content
        } else {
            alternative
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Shows this view only if the user has the specified permission
    func canView(
        _ action: String,
        _ subject: String,
        ability: PureAbility? = nil
    ) -> some View {
        modifier(CanViewModifier(
            action: action,
            subject: subject,
            ability: ability
        ))
    }

    /// Injects an ability into the environment
    func ability(_ ability: PureAbility) -> some View {
        modifier(AbilityModifier(ability: ability))
    }

    /// Shows alternative content when permission is denied
    func permissionBased<Alternative: View>(
        _ action: String,
        _ subject: String,
        ability: PureAbility? = nil,
        @ViewBuilder alternative: () -> Alternative
    ) -> some View {
        modifier(PermissionBasedContentModifier(
            action: action,
            subject: subject,
            ability: ability,
            alternative: alternative()
        ))
    }
}

// MARK: - Permission-Aware Components

/// A button that is automatically disabled based on permissions
public struct PermissionButton: View {
    let title: String
    let action: String
    let subject: String
    let ability: PureAbility?
    let onTap: () -> Void

    @Environment(\.ability) private var environmentAbility
    @State private var hasPermission = false

    public init(
        _ title: String,
        action: String,
        subject: String,
        ability: PureAbility? = nil,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
        self.subject = subject
        self.ability = ability
        self.onTap = onTap
    }

    public var body: some View {
        Button(title) {
            if hasPermission {
                onTap()
            }
        }
        .disabled(!hasPermission)
        .onAppear {
            checkPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PermissionsChanged"))) { _ in
            checkPermission()
        }
    }

    private func checkPermission() {
        let currentAbility = ability ?? environmentAbility
        hasPermission = currentAbility?.canSync(action, subject) ?? false
    }
}

/// A navigation link that only appears if user has permission
public struct PermissionLink<Destination: View>: View {
    let title: String
    let action: String
    let subject: String
    let ability: PureAbility?
    let destination: Destination

    @Environment(\.ability) private var environmentAbility

    public init(
        _ title: String,
        action: String,
        subject: String,
        ability: PureAbility? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.action = action
        self.subject = subject
        self.ability = ability
        self.destination = destination()
    }

    public var body: some View {
        let currentAbility = ability ?? environmentAbility

        if let currentAbility = currentAbility,
           currentAbility.canSync(action, subject) ?? false
        {
            NavigationLink(title, destination: destination)
        }
    }
}

/// A section that only shows if user has permission
public struct PermissionSection<Content: View>: View {
    let action: String
    let subject: String
    let ability: PureAbility?
    let content: Content

    @Environment(\.ability) private var environmentAbility

    public init(
        action: String,
        subject: String,
        ability: PureAbility? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.subject = subject
        self.ability = ability
        self.content = content()
    }

    public var body: some View {
        content
            .canView(action, subject, ability: ability)
    }
}

// MARK: - Example Usage

struct ExampleView: View {
    @Environment(\.ability) private var ability

    var body: some View {
        VStack {
            // Only show if user can read posts
            Text("Welcome!")
                .canView("read", "post")

            // Show different content based on permissions
            Text("Admin Panel")
                .permissionBased("manage", "users") {
                    Text("You need admin access")
                        .foregroundColor(.red)
                }

            // Permission-aware button
            PermissionButton("Delete", action: "delete", subject: "post") {
                deletePost()
            }

            // Permission-aware navigation
            PermissionLink("Settings", action: "update", subject: "settings") {
                Text("Settings Content")
            }

            // Permission-aware section
            PermissionSection(action: "manage", subject: "content") {
                VStack {
                    Text("Content Management")
                    Button("Edit Article") {}
                    Button("Delete Article") {}
                }
            }
        }
    }

    func deletePost() {
        // Delete implementation
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
    }
}
