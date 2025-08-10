import Foundation
import SwiftUI

// MARK: - @Permitted Property Wrapper

/// A property wrapper that checks permissions before accessing a value
///
/// Usage:
/// ```swift
/// @Permitted(action: "read", subject: "Article")
/// var articleData: ArticleData?
/// ```
@propertyWrapper @MainActor
public struct Permitted<Value> {
    private let action: Action
    private let subject: SubjectType
    private let ability: PureAbility?
    private let defaultValue: Value
    private var storedValue: Value

    public init(
        wrappedValue: Value,
        action: String,
        subject: String,
        ability: PureAbility? = nil
    ) {
        storedValue = wrappedValue
        self.action = Action(action)
        self.subject = SubjectType(subject)
        self.ability = ability
        defaultValue = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            // Get ability from environment if not provided
            let currentAbility = ability ?? PermissionContext.shared.currentAbility

            // Check permission synchronously
            if let currentAbility = currentAbility,
               currentAbility.canSync(action.value, subject.value) ?? false
            {
                return storedValue
            }

            // Return default value if no permission
            return defaultValue
        }
        set {
            // Check write permission before setting
            let currentAbility = ability ?? PermissionContext.shared.currentAbility

            if let currentAbility = currentAbility,
               currentAbility.canSync(action.value, subject.value) ?? false
            {
                storedValue = newValue
            }
        }
    }

    public var projectedValue: PermissionState {
        let currentAbility = ability ?? PermissionContext.shared.currentAbility
        let hasPermission = currentAbility?.canSync(action.value, subject.value) ?? false

        return PermissionState(
            hasPermission: hasPermission,
            action: action,
            subject: subject
        )
    }
}

/// State information about a permission check
public struct PermissionState {
    public let hasPermission: Bool
    public let action: Action
    public let subject: SubjectType
}

// MARK: - @CanAccess Property Wrapper

/// A property wrapper that protects method/property access based on permissions
///
/// Usage:
/// ```swift
/// @CanAccess(action: "update", subject: "Post")
/// func updatePost() { ... }
/// ```
@propertyWrapper @MainActor
public struct CanAccess<Value> {
    private let action: Action
    private let subject: SubjectType
    private let ability: PureAbility?
    private let onDenied: (() -> Void)?
    private var value: Value

    public init(
        wrappedValue: Value,
        action: String,
        subject: String,
        ability: PureAbility? = nil,
        onDenied: (() -> Void)? = nil
    ) {
        value = wrappedValue
        self.action = Action(action)
        self.subject = SubjectType(subject)
        self.ability = ability
        self.onDenied = onDenied
    }

    public var wrappedValue: Value {
        get {
            // Check permission
            let currentAbility = ability ?? PermissionContext.shared.currentAbility

            if let currentAbility = currentAbility,
               !(currentAbility.canSync(action.value, subject.value) ?? false)
            {
                // Call denied handler if permission check fails
                onDenied?()

                // For functions, return a no-op function
                if Value.self == (() -> Void).self {
                    return {} as! Value
                }
            }

            return value
        }
        set {
            // Check write permission
            let currentAbility = ability ?? PermissionContext.shared.currentAbility

            if let currentAbility = currentAbility,
               currentAbility.canSync(action.value, subject.value) ?? false
            {
                value = newValue
            } else {
                onDenied?()
            }
        }
    }

    public var projectedValue: CanAccessState {
        let currentAbility = ability ?? PermissionContext.shared.currentAbility
        let canAccess = currentAbility?.canSync(action.value, subject.value) ?? false

        return CanAccessState(
            canAccess: canAccess,
            action: action,
            subject: subject
        )
    }
}

/// State information about access permission
public struct CanAccessState {
    public let canAccess: Bool
    public let action: Action
    public let subject: SubjectType
}

// MARK: - Permission Context

/// Global permission context for property wrappers
@MainActor
public class PermissionContext: ObservableObject {
    public static let shared = PermissionContext()

    @Published public var currentAbility: PureAbility?

    private init() {}

    public func setAbility(_ ability: PureAbility) {
        currentAbility = ability
    }
}

// MARK: - Compile-time Permission Hints

/// Protocol for marking types that require specific permissions
public protocol PermissionRequired {
    static var requiredPermissions: [(action: String, subject: String)] { get }
}

/// Attribute to mark methods requiring permissions (for documentation)
/// Note: Swift doesn't support custom attributes that affect compilation,
/// but this serves as documentation
public struct RequiresPermission {
    public let action: String
    public let subject: String

    public init(action: String, subject: String) {
        self.action = action
        self.subject = subject
    }
}

// MARK: - Dynamic Permission Updates

/// Extension to support dynamic updates
public extension PermissionContext {
    /// Notify all observers of permission changes
    func permissionsDidChange() {
        objectWillChange.send()
    }
}

// Example usage with @Observable
@MainActor
public class PermissionAwareViewModel: ObservableObject {
    @Permitted(wrappedValue: "", action: "read", subject: "user")
    var userData: String

    @Permitted(wrappedValue: "", action: "update", subject: "household")
    var householdName: String

    @CanAccess(wrappedValue: {
        print("Deleting post...")
    }, action: "delete", subject: "post", onDenied: {
        print("Delete permission denied")
    })
    var deletePost: () -> Void

    public init() {}

    // Method with permission requirement documentation
    // @RequiresPermission(action: "manage", subject: "content")
    public func manageContent() {
        // Implementation
    }
}
