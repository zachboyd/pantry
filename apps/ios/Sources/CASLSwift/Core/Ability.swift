import Foundation
import Observation

/// The main class for checking permissions in CASLSwift
/// 
/// This class provides the primary interface for permission checking,
/// following the same API as the JavaScript CASL library.
@Observable @MainActor
public class Ability<A: RawRepresentable, S: RawRepresentable> where A.RawValue == String, S.RawValue == String {
    
    // MARK: - Properties
    
    /// The underlying rule engine
    private let ruleEngine: RuleEngine
    
    /// Condition evaluator for this ability
    private let conditionEvaluator: ConditionEvaluator
    
    /// Loading state for UI binding
    public private(set) var isLoading = false
    
    /// Last error encountered
    public private(set) var lastError: Error?
    
    /// Subject type detector
    private var subjectTypeDetector: SubjectTypeDetector?
    
    /// Initialization state tracking
    internal enum InitializationState {
        case uninitialized
        case initializing
        case ready
        case failed(Error)
    }
    
    /// Current initialization state
    internal var initState: InitializationState = .ready
    
    /// Rules pending initialization
    private var pendingRules: [Rule]?
    
    // MARK: - Initialization
    
    /// Initialize with a rule engine and condition evaluator (already initialized)
    internal init(
        ruleEngine: RuleEngine,
        conditionEvaluator: ConditionEvaluator,
        state: InitializationState = .ready
    ) {
        self.ruleEngine = ruleEngine
        self.conditionEvaluator = conditionEvaluator
        self.initState = state
    }
    
    /// Initialize empty ability (no rules)
    public init() {
        self.ruleEngine = RuleEngine()
        self.conditionEvaluator = BasicConditionEvaluator()
        self.initState = .ready
        
        // Set evaluator synchronously in a Task
        Task {
            await ruleEngine.setConditionEvaluator(conditionEvaluator)
        }
    }
    
    /// Initialize with rules (deferred initialization)
    /// - Warning: You must call `initialize()` before using this ability
    public init(rules: [Rule], deferred: Bool = true) {
        self.ruleEngine = RuleEngine()
        self.conditionEvaluator = BasicConditionEvaluator()
        
        if deferred {
            self.pendingRules = rules
            self.initState = .uninitialized
        } else {
            // For backward compatibility, still fire off the async task
            self.initState = .initializing
            Task {
                await self.ruleEngine.setConditionEvaluator(self.conditionEvaluator)
                await self.ruleEngine.addRules(rules)
                self.initState = .ready
            }
        }
    }
    
    /// Create a fully initialized ability with rules (recommended)
    @MainActor
    public static func create(
        rules: [Rule],
        conditionEvaluator: ConditionEvaluator = BasicConditionEvaluator()
    ) async -> Ability<A, S> {
        let engine = RuleEngine()
        await engine.setConditionEvaluator(conditionEvaluator)
        await engine.addRules(rules)
        
        return Ability(
            ruleEngine: engine,
            conditionEvaluator: conditionEvaluator,
            state: .ready
        )
    }
    
    /// Initialize a deferred ability
    @MainActor
    public func initialize() async throws {
        guard case .uninitialized = initState else {
            if case .failed(let error) = initState {
                throw error
            }
            return // Already initialized or initializing
        }
        
        initState = .initializing
        
        await ruleEngine.setConditionEvaluator(conditionEvaluator)
        if let rules = pendingRules {
            await ruleEngine.addRules(rules)
            pendingRules = nil
        }
        initState = .ready
    }
    
    /// Ensure the ability is initialized before use
    private func ensureInitialized() async {
        switch initState {
        case .uninitialized:
            try? await initialize()
        case .initializing:
            // Wait for initialization to complete
            var attempts = 0
            while attempts < 100 {
                if case .initializing = initState {
                    await Task.yield()
                    attempts += 1
                } else {
                    break
                }
            }
        case .ready:
            return
        case .failed:
            return // Will return default "not allowed"
        }
    }
    
    // MARK: - Permission Checking
    
    /// Check if the user can perform an action on a subject
    public func can(_ action: A, _ subject: any Subject) async -> Bool {
        await ensureInitialized()
        return await can(Action(action.rawValue), subject)
    }
    
    /// Check if the user can perform an action on a subject type
    public func can(_ action: A, _ subjectType: S) async -> Bool {
        await ensureInitialized()
        // Create a dummy subject for type-based checks
        let dummySubject = TypedSubject(type: SubjectType(subjectType.rawValue))
        return await can(Action(action.rawValue), dummySubject)
    }
    
    /// Check if the user can perform a raw action on a subject
    public func can(_ action: Action, _ subject: any Subject) async -> Bool {
        await ensureInitialized()
        return await ruleEngine.can(action, subject)
    }
    
    /// Check if the user cannot perform an action on a subject
    public func cannot(_ action: A, _ subject: any Subject) async -> Bool {
        await ensureInitialized()
        return await cannot(Action(action.rawValue), subject)
    }
    
    /// Check if the user cannot perform an action on a subject type
    public func cannot(_ action: A, _ subjectType: S) async -> Bool {
        await ensureInitialized()
        let dummySubject = TypedSubject(type: SubjectType(subjectType.rawValue))
        return await cannot(Action(action.rawValue), dummySubject)
    }
    
    /// Check if the user cannot perform a raw action on a subject
    public func cannot(_ action: Action, _ subject: any Subject) async -> Bool {
        await ensureInitialized()
        return await ruleEngine.cannot(action, subject)
    }
    
    // MARK: - Synchronous Convenience Methods
    
    /// Check if rules are ready for synchronous checks
    public var isReady: Bool {
        if case .ready = initState {
            return true
        }
        return false
    }
    
    /// Synchronous check if the user can perform an action (only works if already initialized)
    /// - Returns: nil if not initialized, boolean result otherwise
    @MainActor
    public func canSync(_ action: A, _ subject: any Subject) -> Bool? {
        guard isReady else { return nil }
        
        // Create a synchronous task for checking
        let task = Task { @MainActor in
            await ruleEngine.can(Action(action.rawValue), subject)
        }
        
        // Since we're on MainActor and rules are loaded, this should complete immediately
        // This is safe because the rule checking itself doesn't require async when rules are loaded
        var result: Bool?
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 0.01) // Very short timeout since rules are loaded
        return result
    }
    
    /// Synchronous check if the user can perform an action on a subject type
    @MainActor
    public func canSync(_ action: A, _ subjectType: S) -> Bool? {
        guard isReady else { return nil }
        let dummySubject = TypedSubject(type: SubjectType(subjectType.rawValue))
        return canSync(action, dummySubject)
    }
    
    /// Synchronous check if the user cannot perform an action
    @MainActor
    public func cannotSync(_ action: A, _ subject: any Subject) -> Bool? {
        guard let can = canSync(action, subject) else { return nil }
        return !can
    }
    
    /// Synchronous check if the user cannot perform an action on a subject type
    @MainActor
    public func cannotSync(_ action: A, _ subjectType: S) -> Bool? {
        guard let can = canSync(action, subjectType) else { return nil }
        return !can
    }
    
    // MARK: - Field Permissions
    
    /// Get permitted fields for an action on a subject
    public func permittedFieldsBy(_ action: A, _ subject: any Subject) async -> Set<String>? {
        await ensureInitialized()
        return await ruleEngine.permittedFieldsBy(Action(action.rawValue), subject)
    }
    
    /// Get permitted fields for an action on a subject type
    public func permittedFieldsBy(_ action: A, _ subjectType: S) async -> Set<String>? {
        await ensureInitialized()
        let dummySubject = TypedSubject(type: SubjectType(subjectType.rawValue))
        return await ruleEngine.permittedFieldsBy(Action(action.rawValue), dummySubject)
    }
    
    // MARK: - Rule Management
    
    /// Update rules from an array
    public func update(_ rules: [Rule]) async {
        isLoading = true
        defer { isLoading = false }
        
        await ruleEngine.clear()
        await ruleEngine.addRules(rules)
        lastError = nil
    }
    
    /// Add a single rule
    public func addRule(_ rule: Rule) async {
        await ruleEngine.addRule(rule)
    }
    
    /// Clear all rules
    public func clear() async {
        await ruleEngine.clear()
    }
    
    // MARK: - Subject Type Detection
    
    /// Set a custom subject type detector
    public func setSubjectTypeDetector(_ detector: SubjectTypeDetector) {
        self.subjectTypeDetector = detector
    }
    
    // MARK: - JSON Import/Export
    
    /// Export current rules as JSON data
    public func toJSON() async throws -> Data {
        let rules = await ruleEngine.getRules()
        return try PermissionCoder.encode(rules: rules)
    }
    
    /// Export current rules as JSON string
    public func toJSONString() async throws -> String {
        let rules = await ruleEngine.getRules()
        return try PermissionCoder.encodeToString(rules: rules)
    }
    
    /// Export current rules as PermissionSet with metadata
    public func toPermissionSet(
        version: String = PermissionCoder.currentVersion,
        metadata: [String: Any]? = nil
    ) async throws -> Data {
        let rules = await ruleEngine.getRules()
        return try PermissionCoder.encode(rules: rules, version: version, metadata: metadata)
    }
    
    /// Update rules from JSON data
    public func update(fromJSON data: Data) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rules = try PermissionCoder.decodeRules(from: data)
            await ruleEngine.clear()
            await ruleEngine.addRules(rules)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Update rules from JSON string
    public func update(fromJSONString jsonString: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rules = try PermissionCoder.decodeRules(from: jsonString)
            await ruleEngine.clear()
            await ruleEngine.addRules(rules)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Static factory method to create an Ability from JSON
    @MainActor
    public static func from(json data: Data) throws -> Ability<A, S> {
        let rules = try PermissionCoder.decodeRules(from: data)
        return Ability(rules: rules)
    }
    
    /// Static factory method to create an Ability from JSON string
    @MainActor
    public static func from(jsonString: String) throws -> Ability<A, S> {
        let rules = try PermissionCoder.decodeRules(from: jsonString)
        return Ability(rules: rules)
    }
    
    /// Detect subject type for an object
    public func detectSubjectType(of object: Any) -> SubjectType? {
        if let subject = object as? Subject {
            return subject.subjectType
        }
        return subjectTypeDetector?.detectSubjectType(of: object)
    }
}

// MARK: - Helper Types

/// A dummy subject for type-based permission checks
private struct TypedSubject: Subject, Sendable {
    static var subjectType: SubjectType { "TypedSubject" }
    
    let type: SubjectType
    
    var subjectType: SubjectType { type }
}

// MARK: - Testing Support

#if DEBUG
public extension Ability {
    /// Create an ability synchronously for testing
    /// - Warning: This blocks and should only be used in tests
    @MainActor
    static func createForTesting(rules: [Rule]) -> Ability<A, S> {
        let ability = Ability<A, S>()
        
        // Block until rules are added
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await ability.ruleEngine.setConditionEvaluator(ability.conditionEvaluator)
            await ability.ruleEngine.addRules(rules)
            ability.initState = .ready
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        return ability
    }
}
#endif

// MARK: - Subject Type Detection Protocol

/// Protocol for custom subject type detection
public protocol SubjectTypeDetector: Sendable {
    /// Detect the subject type of an object
    func detectSubjectType(of object: Any) -> SubjectType?
}