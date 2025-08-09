import Foundation
import Combine

// MARK: - Observable Ability

/// Protocol for abilities that can notify about changes
public protocol ObservableAbility: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
}

// MARK: - Reactive Ability

/// An ability class that supports reactive updates
@MainActor
public final class ReactiveAbility: ObservableObject, ObservableAbility {
    private var ability: PureAbility
    @Published private var updateTrigger = false
    
    public init(rules: [Rule] = [], deferred: Bool = false) {
        self.ability = PureAbility(rules: rules, deferred: deferred)
    }
    
    /// Create a fully initialized reactive ability
    public static func create(rules: [Rule]) async -> ReactiveAbility {
        let reactive = ReactiveAbility(rules: [], deferred: true)
        reactive.ability = await PureAbility.create(rules: rules)
        return reactive
    }
    
    // Delegate permission checking to internal ability (async)
    public func can(_ action: String, _ subject: String) async -> Bool {
        await ability.can(action, subject)
    }
    
    public func can(_ action: String, _ subject: any Subject) async -> Bool {
        await ability.can(action, subject)
    }
    
    public func cannot(_ action: String, _ subject: String) async -> Bool {
        await ability.cannot(action, subject)
    }
    
    public func cannot(_ action: String, _ subject: any Subject) async -> Bool {
        await ability.cannot(action, subject)
    }
    
    // Synchronous versions (returns nil if not ready)
    public func canSync(_ action: String, _ subject: String) -> Bool? {
        ability.canSync(action, subject)
    }
    
    public func canSync(_ action: String, _ subject: any Subject) -> Bool? {
        ability.canSync(action, subject)
    }
    
    public func cannotSync(_ action: String, _ subject: String) -> Bool? {
        ability.cannotSync(action, subject)
    }
    
    public func cannotSync(_ action: String, _ subject: any Subject) -> Bool? {
        ability.cannotSync(action, subject)
    }
    
    public func update(_ rules: [Rule]) async {
        await ability.update(rules)
        updateTrigger.toggle()
    }
    
    public func addRule(_ rule: Rule) async {
        await ability.addRule(rule)
        updateTrigger.toggle()
    }
    
    public func clear() async {
        await ability.clear()
        updateTrigger.toggle()
    }
    
    /// Creates a publisher for a specific permission check
    public func publisher(for action: String, _ subject: String) -> AnyPublisher<Bool, Never> {
        // Combine the initial value with updates
        // Use sync version for publisher (returns false if not ready)
        let initialValue = Just(canSync(action, subject) ?? false)
        let updates = objectWillChange
            .map { [weak self] _ in
                self?.canSync(action, subject) ?? false
            }
        
        return initialValue
            .merge(with: updates)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - Permission Change Notifications

/// Notification center for permission changes
@MainActor
public final class PermissionNotificationCenter {
    public static let shared = PermissionNotificationCenter()
    
    private let subject = PassthroughSubject<PermissionChange, Never>()
    
    public var publisher: AnyPublisher<PermissionChange, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    /// Notify about permission changes
    public func notifyChange(_ change: PermissionChange) {
        subject.send(change)
    }
}

/// Represents a permission change
public struct PermissionChange {
    public let action: String
    public let subject: String
    public let previousValue: Bool
    public let newValue: Bool
    public let timestamp: Date
    
    public init(
        action: String,
        subject: String,
        previousValue: Bool,
        newValue: Bool,
        timestamp: Date = Date()
    ) {
        self.action = action
        self.subject = subject
        self.previousValue = previousValue
        self.newValue = newValue
        self.timestamp = timestamp
    }
}

// MARK: - Combine Operators

extension Publisher where Output == Bool, Failure == Never {
    /// Filters elements based on permission being granted
    public func whenPermitted() -> Publishers.Filter<Self> {
        filter { $0 }
    }
    
    /// Filters elements based on permission being denied
    public func whenDenied() -> Publishers.Filter<Self> {
        filter { !$0 }
    }
}

extension Publisher {
    /// Gates the publisher based on a permission check
    @MainActor
    public func requirePermission(
        _ ability: ReactiveAbility,
        action: String,
        subject: String
    ) -> AnyPublisher<Output, Failure> {
        let hasPermission = ability.canSync(action, subject) ?? false
        
        if hasPermission {
            return self.eraseToAnyPublisher()
        } else {
            return Empty<Output, Failure>().eraseToAnyPublisher()
        }
    }
}

// MARK: - SwiftUI Integration with Combine

/// A view model that automatically updates when permissions change
@MainActor
public class PermissionAwareObservableObject: ObservableObject {
    @Published public var ability: ReactiveAbility?
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(ability: ReactiveAbility? = nil) {
        self.ability = ability
        setupBindings()
    }
    
    private func setupBindings() {
        // Re-publish ability changes
        $ability
            .compactMap { $0 }
            .flatMap { $0.objectWillChange }
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Listen for global permission changes
        PermissionNotificationCenter.shared.publisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public func checkPermission(_ action: String, _ subject: String) -> Bool {
        ability?.canSync(action, subject) ?? false
    }
    
    public func permissionPublisher(_ action: String, _ subject: String) -> AnyPublisher<Bool, Never> {
        guard let ability = ability else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return ability.publisher(for: action, subject)
    }
}

// MARK: - Example Usage

class ExampleViewModel: PermissionAwareObservableObject {
    @Published var posts: [String] = []
    
    private var postCancellable: AnyCancellable?
    
    override init(ability: ReactiveAbility? = nil) {
        super.init(ability: ability)
        
        // Only load posts if user has read permission
        postCancellable = permissionPublisher("read", "post")
            .whenPermitted()
            .sink { [weak self] _ in
                self?.loadPosts()
            }
    }
    
    private func loadPosts() {
        posts = ["Post 1", "Post 2", "Post 3"]
    }
    
    func deletePost(at index: Int) {
        // Check permission before deleting
        guard checkPermission("delete", "post") else { return }
        posts.remove(at: index)
    }
}