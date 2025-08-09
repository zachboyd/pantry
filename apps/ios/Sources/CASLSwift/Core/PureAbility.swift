import Foundation
import Observation

/// A non-generic version of Ability that works with string-based actions and subjects
/// This is easier to use when you don't need type safety for actions and subjects
@Observable @MainActor
public final class PureAbility {
    
    // MARK: - Properties
    
    /// The underlying generic ability
    private var ability: Ability<DynamicAction, DynamicSubject>
    
    /// Loading state for UI binding
    public var isLoading: Bool {
        ability.isLoading
    }
    
    /// Last error encountered
    public var lastError: Error? {
        ability.lastError
    }
    
    /// Check if the ability is ready
    public var isReady: Bool {
        ability.isReady
    }
    
    // MARK: - Initialization
    
    /// Initialize empty ability (no rules)
    public init() {
        self.ability = Ability()
    }
    
    /// Initialize with rules (deferred initialization)
    /// - Warning: You must call `initialize()` before using this ability
    public init(rules: [Rule], deferred: Bool = true) {
        self.ability = Ability(rules: rules, deferred: deferred)
    }
    
    /// Create a fully initialized ability with rules (recommended)
    @MainActor
    public static func create(rules: [Rule]) async -> PureAbility {
        let ability = PureAbility()
        ability.ability = await Ability<DynamicAction, DynamicSubject>.create(rules: rules)
        return ability
    }
    
    /// Initialize a deferred ability
    @MainActor
    public func initialize() async throws {
        try await ability.initialize()
    }
    
    
    // MARK: - Permission Checking (Async)
    
    /// Check if the user can perform an action on a subject
    public func can(_ action: String, _ subject: any Subject) async -> Bool {
        await ability.can(DynamicAction(action), subject)
    }
    
    /// Check if the user can perform an action on a subject type
    public func can(_ action: String, _ subjectType: String) async -> Bool {
        await ability.can(DynamicAction(action), DynamicSubject(subjectType))
    }
    
    /// Check if the user cannot perform an action on a subject
    public func cannot(_ action: String, _ subject: any Subject) async -> Bool {
        await ability.cannot(DynamicAction(action), subject)
    }
    
    /// Check if the user cannot perform an action on a subject type
    public func cannot(_ action: String, _ subjectType: String) async -> Bool {
        await ability.cannot(DynamicAction(action), DynamicSubject(subjectType))
    }
    
    // MARK: - Permission Checking (Sync)
    
    /// Synchronous check if the user can perform an action (only works if already initialized)
    /// - Returns: nil if not initialized, boolean result otherwise
    public func canSync(_ action: String, _ subject: any Subject) -> Bool? {
        ability.canSync(DynamicAction(action), subject)
    }
    
    /// Synchronous check if the user can perform an action on a subject type
    public func canSync(_ action: String, _ subjectType: String) -> Bool? {
        ability.canSync(DynamicAction(action), DynamicSubject(subjectType))
    }
    
    /// Synchronous check if the user cannot perform an action
    public func cannotSync(_ action: String, _ subject: any Subject) -> Bool? {
        ability.cannotSync(DynamicAction(action), subject)
    }
    
    /// Synchronous check if the user cannot perform an action on a subject type
    public func cannotSync(_ action: String, _ subjectType: String) -> Bool? {
        ability.cannotSync(DynamicAction(action), DynamicSubject(subjectType))
    }
    
    // MARK: - Field Permissions
    
    /// Get permitted fields for an action on a subject
    public func permittedFieldsBy(_ action: String, _ subject: any Subject) async -> Set<String>? {
        await ability.permittedFieldsBy(DynamicAction(action), subject)
    }
    
    /// Get permitted fields for an action on a subject type
    public func permittedFieldsBy(_ action: String, _ subjectType: String) async -> Set<String>? {
        await ability.permittedFieldsBy(DynamicAction(action), DynamicSubject(subjectType))
    }
    
    // MARK: - Rule Management
    
    /// Update rules from an array
    public func update(_ rules: [Rule]) async {
        await ability.update(rules)
    }
    
    /// Add a single rule
    public func addRule(_ rule: Rule) async {
        await ability.addRule(rule)
    }
    
    /// Clear all rules
    public func clear() async {
        await ability.clear()
    }
    
    // MARK: - JSON Import/Export
    
    /// Export current rules as JSON data
    public func toJSON() async throws -> Data {
        try await ability.toJSON()
    }
    
    /// Export current rules as JSON string
    public func toJSONString() async throws -> String {
        try await ability.toJSONString()
    }
    
    /// Export current rules as PermissionSet with metadata
    public func toPermissionSet(
        version: String = PermissionCoder.currentVersion,
        metadata: [String: Any]? = nil
    ) async throws -> Data {
        try await ability.toPermissionSet(version: version, metadata: metadata)
    }
    
    /// Update rules from JSON data
    public func update(fromJSON data: Data) async throws {
        try await ability.update(fromJSON: data)
    }
    
    /// Update rules from JSON string
    public func update(fromJSONString jsonString: String) async throws {
        try await ability.update(fromJSONString: jsonString)
    }
    
    /// Static factory method to create a PureAbility from JSON
    @MainActor
    public static func from(json data: Data) async throws -> PureAbility {
        let rules = try PermissionCoder.decodeRules(from: data)
        return await PureAbility.create(rules: rules)
    }
    
    /// Static factory method to create a PureAbility from JSON string
    @MainActor
    public static func from(jsonString: String) async throws -> PureAbility {
        let rules = try PermissionCoder.decodeRules(from: jsonString)
        return await PureAbility.create(rules: rules)
    }
    
    // MARK: - Subject Type Detection
    
    /// Set a custom subject type detector
    public func setSubjectTypeDetector(_ detector: SubjectTypeDetector) {
        ability.setSubjectTypeDetector(detector)
    }
    
    /// Detect subject type for an object
    public func detectSubjectType(of object: Any) -> SubjectType? {
        ability.detectSubjectType(of: object)
    }
}

// MARK: - Testing Support

#if DEBUG
public extension PureAbility {
    /// Create an ability synchronously for testing
    /// - Warning: This blocks and should only be used in tests
    @MainActor
    static func createForTesting(rules: [Rule]) -> PureAbility {
        let ability = PureAbility()
        ability.ability = Ability<DynamicAction, DynamicSubject>.createForTesting(rules: rules)
        return ability
    }
}
#endif

// MARK: - Dynamic Action and Subject Types

/// Dynamic action that can represent any string value
private struct DynamicAction: RawRepresentable {
    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    init(_ value: String) {
        self.rawValue = value
    }
}

/// Dynamic subject that can represent any string value
private struct DynamicSubject: RawRepresentable {
    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    init(_ value: String) {
        self.rawValue = value
    }
}