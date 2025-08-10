import Foundation

/// Builder class for creating abilities with a fluent API
///
/// This follows the same pattern as CASL's JavaScript AbilityBuilder
public class AbilityBuilder<A: RawRepresentable, S: RawRepresentable> where A.RawValue == String, S.RawValue == String {
    // MARK: - Properties

    /// Rules being built
    private var rules: [Rule] = []

    /// Current priority for rules (can be adjusted)
    private var currentPriority: Int = 0

    /// Track whether rules came from JSON to preserve insertion order
    private var preserveInsertionOrder: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Fluent API for Rule Building

    /// Allow an action on a subject type
    @discardableResult
    public func can(_ action: A, _ subjectType: S) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action on a subject type with conditions
    @discardableResult
    public func can(_ action: A, _ subjectType: S, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            conditions: Conditions(conditions),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action on a subject type with conditions builder
    @discardableResult
    public func can(_ action: A, _ subjectType: S, where conditionBuilder: () -> [String: Any]) -> Self {
        can(action, subjectType, conditionBuilder())
    }

    /// Allow an action on a subject type with specific fields
    @discardableResult
    public func can(_ action: A, _ subjectType: S, fields: [String]) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            conditions: nil,
            inverted: false,
            fields: fields,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action on a subject type with fields and conditions
    @discardableResult
    public func can(_ action: A, _ subjectType: S, fields: [String], _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            conditions: Conditions(conditions),
            inverted: false,
            fields: fields,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type
    @discardableResult
    public func cannot(_ action: A, _ subjectType: S) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with conditions
    @discardableResult
    public func cannot(_ action: A, _ subjectType: S, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            conditions: Conditions(conditions),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with conditions builder
    @discardableResult
    public func cannot(_ action: A, _ subjectType: S, where conditionBuilder: () -> [String: Any]) -> Self {
        cannot(action, subjectType, conditionBuilder())
    }

    /// Forbid an action on a subject type with specific fields
    @discardableResult
    public func cannot(_ action: A, _ subjectType: S, fields: [String]) -> Self {
        let rule = Rule(
            action: Action(action.rawValue),
            subject: SubjectType(subjectType.rawValue),
            conditions: nil,
            inverted: true,
            fields: fields,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    // MARK: - String-based API (for dynamic rules)

    /// Allow an action (string) on a subject type (string)
    @discardableResult
    public func can(_ action: String, _ subjectType: String) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action (string) on a subject type (string) with conditions
    @discardableResult
    public func can(_ action: String, _ subjectType: String, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: Conditions(conditions),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action (string) on a subject type (string)
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action (string) on a subject type (string) with conditions
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: Conditions(conditions),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    // MARK: - Priority Management

    /// Set the priority for subsequent rules
    @discardableResult
    public func withPriority(_ priority: Int) -> Self {
        currentPriority = priority
        return self
    }

    /// Reset priority to default (0)
    @discardableResult
    public func resetPriority() -> Self {
        currentPriority = 0
        return self
    }

    // MARK: - Build Methods

    /// Build the ability with the defined rules (async - recommended)
    @MainActor
    public func build() async -> Ability<A, S> {
        await Ability.create(rules: rules)
    }

    /// Build the ability with deferred initialization
    /// - Warning: You must call `initialize()` on the returned ability before use
    @MainActor
    public func buildDeferred() -> Ability<A, S> {
        Ability(rules: rules, deferred: true)
    }

    /// Build the ability synchronously for testing
    #if DEBUG
        @MainActor
        public func buildForTesting() -> Ability<A, S> {
            Ability.createForTesting(rules: rules)
        }
    #endif

    /// Get the raw rules without building an ability
    /// Rules are sorted by specificity unless they were loaded from JSON,
    /// in which case insertion order is preserved (as per CASL convention)
    public func getRules() -> [Rule] {
        if preserveInsertionOrder {
            return rules // Preserve original order for JSON-loaded rules
        } else {
            return rules.sorted(by: <) // Sort by specificity for programmatic rules
        }
    }

    /// Clear all rules
    @discardableResult
    public func reset() -> Self {
        rules.removeAll()
        currentPriority = 0
        preserveInsertionOrder = false
        return self
    }

    // MARK: - JSON Import Methods

    /// Add rules from JSON data
    @discardableResult
    public func from(json data: Data) throws -> Self {
        let newRules = try PermissionCoder.decodeRules(from: data)
        rules.append(contentsOf: newRules)
        preserveInsertionOrder = true // JSON rules preserve insertion order
        return self
    }

    /// Add rules from JSON string
    @discardableResult
    public func from(jsonString: String) throws -> Self {
        let newRules = try PermissionCoder.decodeRules(from: jsonString)
        rules.append(contentsOf: newRules)
        preserveInsertionOrder = true // JSON rules preserve insertion order
        return self
    }

    /// Add rules from Permission array
    @discardableResult
    public func from(permissions: [Permission]) -> Self {
        let newRules = permissions.map { $0.toRule() }
        rules.append(contentsOf: newRules)
        return self
    }

    /// Add existing rules
    @discardableResult
    public func from(rules: [Rule]) -> Self {
        self.rules.append(contentsOf: rules)
        return self
    }

    /// Replace all rules with rules from JSON data
    @discardableResult
    public func replaceWith(json data: Data) throws -> Self {
        rules = try PermissionCoder.decodeRules(from: data)
        return self
    }

    /// Replace all rules with rules from JSON string
    @discardableResult
    public func replaceWith(jsonString: String) throws -> Self {
        rules = try PermissionCoder.decodeRules(from: jsonString)
        return self
    }
}

// MARK: - PureAbilityBuilder

/// Non-generic version of AbilityBuilder for easier use
public final class PureAbilityBuilder {
    // MARK: - Properties

    /// Rules being built
    private var rules: [Rule] = []

    /// Current priority for rules
    private var currentPriority: Int = 0

    /// Track whether rules came from JSON to preserve insertion order
    private var preserveInsertionOrder: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Fluent API

    /// Allow an action on a subject type
    @discardableResult
    public func can(_ action: String, _ subjectType: String) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action on a subject type with conditions
    @discardableResult
    public func can(_ action: String, _ subjectType: String, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: Conditions(conditions),
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Allow an action on a subject type with conditions builder
    @discardableResult
    public func can(_ action: String, _ subjectType: String, where conditionBuilder: () -> [String: Any]) -> Self {
        can(action, subjectType, conditionBuilder())
    }

    /// Allow an action on a subject type with specific fields
    @discardableResult
    public func can(_ action: String, _ subjectType: String, fields: [String]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: nil,
            inverted: false,
            fields: fields,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with conditions
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String, _ conditions: [String: Any]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: Conditions(conditions),
            inverted: true,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with conditions builder
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String, where conditionBuilder: () -> [String: Any]) -> Self {
        cannot(action, subjectType, conditionBuilder())
    }

    /// Allow an action on a subject type with priority
    @discardableResult
    public func can(_ action: String, _ subjectType: String, priority: Int) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            priority: priority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with priority
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String, priority: Int) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            inverted: true,
            priority: priority
        )
        rules.append(rule)
        return self
    }

    /// Forbid an action on a subject type with specific fields
    @discardableResult
    public func cannot(_ action: String, _ subjectType: String, fields: [String]) -> Self {
        let rule = Rule(
            action: Action(action),
            subject: SubjectType(subjectType),
            conditions: nil,
            inverted: true,
            fields: fields,
            priority: currentPriority
        )
        rules.append(rule)
        return self
    }

    // MARK: - Build Methods

    /// Build the ability with the defined rules (async - recommended)
    @MainActor
    public func build() async -> PureAbility {
        await PureAbility.create(rules: rules)
    }

    /// Build the ability with deferred initialization
    /// - Warning: You must call `initialize()` on the returned ability before use
    @MainActor
    public func buildDeferred() -> PureAbility {
        PureAbility(rules: rules, deferred: true)
    }

    /// Build the ability synchronously for testing
    #if DEBUG
        @MainActor
        public func buildForTesting() -> PureAbility {
            PureAbility.createForTesting(rules: rules)
        }
    #endif

    /// Get the raw rules without building an ability
    /// Rules are sorted by specificity unless they were loaded from JSON,
    /// in which case insertion order is preserved (as per CASL convention)
    public func getRules() -> [Rule] {
        if preserveInsertionOrder {
            return rules // Preserve original order for JSON-loaded rules
        } else {
            return rules.sorted(by: <) // Sort by specificity for programmatic rules
        }
    }

    /// Clear all rules
    @discardableResult
    public func reset() -> Self {
        rules.removeAll()
        currentPriority = 0
        preserveInsertionOrder = false
        return self
    }

    // MARK: - JSON Import Methods

    /// Add rules from JSON data
    @discardableResult
    public func from(json data: Data) throws -> Self {
        let newRules = try PermissionCoder.decodeRules(from: data)
        rules.append(contentsOf: newRules)
        preserveInsertionOrder = true // JSON rules preserve insertion order
        return self
    }

    /// Add rules from JSON string
    @discardableResult
    public func from(jsonString: String) throws -> Self {
        let newRules = try PermissionCoder.decodeRules(from: jsonString)
        rules.append(contentsOf: newRules)
        preserveInsertionOrder = true // JSON rules preserve insertion order
        return self
    }

    /// Add rules from Permission array
    @discardableResult
    public func from(permissions: [Permission]) -> Self {
        let newRules = permissions.map { $0.toRule() }
        rules.append(contentsOf: newRules)
        return self
    }

    /// Add existing rules
    @discardableResult
    public func from(rules: [Rule]) -> Self {
        self.rules.append(contentsOf: rules)
        return self
    }

    /// Replace all rules with rules from JSON data
    @discardableResult
    public func replaceWith(json data: Data) throws -> Self {
        rules = try PermissionCoder.decodeRules(from: data)
        return self
    }

    /// Replace all rules with rules from JSON string
    @discardableResult
    public func replaceWith(jsonString: String) throws -> Self {
        rules = try PermissionCoder.decodeRules(from: jsonString)
        return self
    }
}
