import Foundation
import Observation

// MARK: - Base ViewModel Protocol

/// Protocol defining common reactive patterns for ViewModels
@MainActor
public protocol BaseViewModelProtocol: Observable {
    associatedtype State
    associatedtype Dependencies

    /// Current state of the ViewModel
    var state: State { get }

    /// Loading states for different operations
    var loadingStates: LoadingStates { get }

    /// Error handling
    var currentError: ViewModelError? { get }

    /// Dependencies injected into the ViewModel
    var dependencies: Dependencies { get }

    /// Initialize with dependencies
    init(dependencies: Dependencies)

    /// Lifecycle methods
    func onAppear() async
    func onDisappear() async
    func refresh() async

    /// Error handling
    func handleError(_ error: Error)
    func clearError()
}

// MARK: - Loading States

/// Manages loading states for different operations
/// Thread-safe implementation using @MainActor for SwiftUI compatibility
@Observable @MainActor
public final class LoadingStates {
    private var _states: [String: Bool] = [:]

    public init() {}

    /// Check if a specific operation is loading
    public func isLoading(_ operation: LoadingOperation) -> Bool {
        _states[operation.rawValue] ?? false
    }

    /// Set loading state for an operation
    public func setLoading(_ operation: LoadingOperation, isLoading: Bool) {
        _states[operation.rawValue] = isLoading
    }

    /// Check if any operation is loading
    public var isAnyLoading: Bool {
        _states.values.contains(true)
    }

    /// Clear all loading states
    public func clearAll() {
        _states.removeAll()
    }
}

/// Common loading operations for Pantry app
public enum LoadingOperation: String, CaseIterable {
    case initial
    case refresh
    case save
    case delete
    case update
    case load
    case sync
    case search
    case filter
    case create
    case send
    case addItem
    case removeItem
    case updateQuantity
    case addMember
    case removeMember
    case generateList
    case analyzeReceipt

    @MainActor
    public var displayName: String {
        switch self {
        case .initial: return L("loading.operation.initial")
        case .refresh: return L("loading.operation.refresh")
        case .save: return L("loading.operation.save")
        case .delete: return L("loading.operation.delete")
        case .update: return L("loading.operation.update")
        case .load: return L("loading.operation.load")
        case .sync: return L("loading.operation.sync")
        case .search: return L("loading.operation.search")
        case .filter: return L("loading.operation.filter")
        case .create: return L("loading.operation.create")
        case .send: return L("loading.operation.send")
        case .addItem: return L("loading.operation.add_item")
        case .removeItem: return L("loading.operation.remove_item")
        case .updateQuantity: return L("loading.operation.update_quantity")
        case .addMember: return L("loading.operation.add_member")
        case .removeMember: return L("loading.operation.remove_member")
        case .generateList: return L("loading.operation.generate_list")
        case .analyzeReceipt: return L("loading.operation.analyze_receipt")
        }
    }
}

// MARK: - ViewModel Errors

/// Errors that can occur in ViewModels
public enum ViewModelError: Error, @preconcurrency LocalizedError, Equatable {
    case networkUnavailable
    case unauthorized
    case forbidden
    case notFound
    case validationFailed([ValidationError])
    case operationFailed(String)
    case repositoryError(String)
    case householdNotFound
    case itemNotFound
    case memberNotFound
    case insufficientPermissions
    case storageError(String)
    case unknown(String)

    @MainActor
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return L("error.network_unavailable")
        case .unauthorized:
            return L("error.unauthorized")
        case .forbidden:
            return L("error.forbidden")
        case .notFound:
            return L("error.not_found")
        case let .validationFailed(errors):
            return errors.first?.localizedDescription ?? L("error.validation_failed")
        case let .operationFailed(message):
            return L("error.operation_failed", message)
        case let .repositoryError(message):
            return L("error.repository_error", message)
        case .householdNotFound:
            return L("error.household_not_found")
        case .itemNotFound:
            return L("error.item_not_found")
        case .memberNotFound:
            return L("error.member_not_found")
        case .insufficientPermissions:
            return L("error.insufficient_permissions")
        case let .storageError(message):
            return L("error.storage_error", message)
        case let .unknown(message):
            return L("error.unknown", message)
        }
    }

    @MainActor
    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return L("error.recovery.network_unavailable")
        case .unauthorized:
            return L("error.recovery.unauthorized")
        case .forbidden:
            return L("error.recovery.forbidden")
        case .notFound:
            return L("error.recovery.not_found")
        case .validationFailed:
            return L("error.recovery.validation_failed")
        case .operationFailed, .repositoryError, .storageError:
            return L("error.recovery.try_later")
        case .householdNotFound:
            return L("error.recovery.household_not_found")
        case .itemNotFound:
            return L("error.recovery.item_not_found")
        case .memberNotFound:
            return L("error.recovery.member_not_found")
        case .insufficientPermissions:
            return L("error.recovery.insufficient_permissions")
        case .unknown:
            return L("error.recovery.unknown")
        }
    }

    public static func == (lhs: ViewModelError, rhs: ViewModelError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.householdNotFound, .householdNotFound),
             (.itemNotFound, .itemNotFound),
             (.memberNotFound, .memberNotFound),
             (.insufficientPermissions, .insufficientPermissions):
            return true
        case let (.validationFailed(lhsErrors), .validationFailed(rhsErrors)):
            return lhsErrors == rhsErrors
        case let (.operationFailed(lhsMessage), .operationFailed(rhsMessage)),
             let (.repositoryError(lhsMessage), .repositoryError(rhsMessage)),
             let (.storageError(lhsMessage), .storageError(rhsMessage)),
             let (.unknown(lhsMessage), .unknown(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Validation Error

/// Validation errors for form fields
public struct ValidationError: Error, LocalizedError, Equatable {
    public let field: String
    public let message: String
    public let code: String?

    public init(field: String, message: String, code: String? = nil) {
        self.field = field
        self.message = message
        self.code = code
    }

    public var errorDescription: String? {
        message
    }

    // Common validation errors for Pantry
    public static func required(_ field: String) -> ValidationError {
        ValidationError(field: field, message: "This field is required", code: "required")
    }

    public static func invalidEmail(_ field: String = "email") -> ValidationError {
        ValidationError(field: field, message: "Please enter a valid email address", code: "invalid_email")
    }

    public static func tooShort(_ field: String, minLength: Int) -> ValidationError {
        ValidationError(field: field, message: "\(field) must be at least \(minLength) characters", code: "too_short")
    }

    public static func tooLong(_ field: String, maxLength: Int) -> ValidationError {
        ValidationError(field: field, message: "\(field) must be no more than \(maxLength) characters", code: "too_long")
    }

    public static func invalidQuantity(_ field: String = "quantity") -> ValidationError {
        ValidationError(field: field, message: "Please enter a valid quantity", code: "invalid_quantity")
    }

    public static func duplicateItem(_ field: String = "item") -> ValidationError {
        ValidationError(field: field, message: "This item already exists", code: "duplicate_item")
    }

    public static func householdNameTaken(_ field: String = "name") -> ValidationError {
        ValidationError(field: field, message: "This household name is already taken", code: "household_name_taken")
    }
}

// MARK: - Base ViewModel Implementation

/// Base implementation for @Observable ViewModels with reactive patterns
@Observable @MainActor
open class BaseReactiveViewModel<State, Dependencies>: BaseViewModelProtocol {
    private nonisolated static var logger: Logger { Logger(category: "BaseReactiveViewModel") }

    // MARK: - Published Properties

    public private(set) var state: State
    public let loadingStates = LoadingStates()
    public private(set) var currentError: ViewModelError?
    public let dependencies: Dependencies

    // MARK: - Private Properties

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private let errorLogger = Logger(category: "ViewModelError")
    private var streamTasks: [String: Task<Void, Never>] = [:]
    
    /// Collection of all WatchedResult instances for automatic cleanup
    /// Using type-erased array to store different generic types
    private var managedWatches: [any WatchedResultProtocol] = []

    // MARK: - Initialization

    public required init(dependencies: Dependencies, initialState: State) {
        self.dependencies = dependencies
        state = initialState

        Self.logger.debug("ViewModel initialized: \(String(describing: type(of: self)))")
    }

    public required convenience init(dependencies _: Dependencies) {
        // Note: This convenience initializer should be overridden in subclasses that need
        // additional initialization parameters. For now, we'll use preconditionFailure
        // which is safer than fatalError as it can be disabled in release builds.
        preconditionFailure("init(dependencies:) must be overridden in subclass \(String(describing: Self.self))")
    }

    // MARK: - Lifecycle

    open func onAppear() async {
        Self.logger.debug("ViewModel appeared: \(String(describing: type(of: self)))")
        // Override in subclasses
    }

    open func onDisappear() async {
        Self.logger.debug("ViewModel disappeared: \(String(describing: type(of: self)))")
        cancelAllTasks()
        stopAllStreams()
        stopAllWatches()
    }
    
    // MARK: - Watch Management
    
    /// Register a WatchedResult to be automatically cleaned up
    public func registerWatch<T>(_ watch: WatchedResult<T>) {
        managedWatches.append(watch)
    }
    
    /// Stop all registered watches
    private func stopAllWatches() {
        Self.logger.debug("Stopping \(managedWatches.count) watches")
        for watch in managedWatches {
            watch.stopWatching()
        }
        managedWatches.removeAll()
    }

    open func refresh() async {
        Self.logger.debug("Refreshing ViewModel: \(String(describing: type(of: self)))")
        // Override in subclasses
    }

    // MARK: - State Management

    /// Update the state in a thread-safe manner
    public func updateState(_ newState: State) {
        state = newState
    }

    /// Update state using a closure
    public func updateState(_ update: (inout State) -> Void) {
        var newState = state
        update(&newState)
        state = newState
    }

    // MARK: - Error Handling

    public func handleError(_ error: Error) {
        errorLogger.error("ViewModel error: \(error)")

        let viewModelError: ViewModelError

        switch error {
        case let vmError as ViewModelError:
            viewModelError = vmError
        case let validationError as ValidationError:
            viewModelError = .validationFailed([validationError])
        default:
            viewModelError = .unknown(error.localizedDescription)
        }

        currentError = viewModelError
    }

    public func clearError() {
        currentError = nil
    }

    // MARK: - Task Management

    /// Execute an async task with loading state management
    public func executeTask(
        _ operation: LoadingOperation,
        task: @escaping () async throws -> Void
    ) {
        let taskKey = operation.rawValue

        // Cancel existing task if running
        activeTasks[taskKey]?.cancel()

        activeTasks[taskKey] = Task {
            loadingStates.setLoading(operation, isLoading: true)
            clearError()

            do {
                try await task()
                Self.logger.debug("Task completed successfully: \(operation.rawValue)")
            } catch {
                Self.logger.error("Task failed: \(operation.rawValue) - \(error)")
                handleError(error)
            }

            loadingStates.setLoading(operation, isLoading: false)
            activeTasks.removeValue(forKey: taskKey)
        }
    }

    /// Execute a task that returns a value
    public func executeTask<T: Sendable>(
        _ operation: LoadingOperation,
        task: @escaping @Sendable () async throws -> T
    ) async -> T? {
        let taskKey = operation.rawValue

        // Cancel existing task if running
        activeTasks[taskKey]?.cancel()

        let result = await Task<T?, Never> {
            loadingStates.setLoading(operation, isLoading: true)
            clearError()

            defer {
                loadingStates.setLoading(operation, isLoading: false)
                activeTasks.removeValue(forKey: taskKey)
            }

            do {
                let result = try await task()
                Self.logger.debug("Task completed successfully: \(operation.rawValue)")
                return result
            } catch {
                Self.logger.error("Task failed: \(operation.rawValue) - \(error)")
                handleError(error)
                return nil
            }
        }.value

        return result
    }

    /// Cancel all active tasks
    public func cancelAllTasks() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        loadingStates.clearAll()
    }

    /// Cancel a specific task
    public func cancelTask(_ operation: LoadingOperation) {
        let taskKey = operation.rawValue
        activeTasks[taskKey]?.cancel()
        activeTasks.removeValue(forKey: taskKey)
        loadingStates.setLoading(operation, isLoading: false)
    }

    // MARK: - Reactive Stream Helpers

    /// Generic method for watching reactive streams with automatic task management
    public func watchStream<T: Sendable>(
        key: String,
        stream: @escaping @Sendable () -> AsyncStream<T>,
        debounce _: TimeInterval = 0,
        handler: @escaping @Sendable (T) async -> Void
    ) {
        // Cancel existing stream if running
        streamTasks[key]?.cancel()

        let task = Task {
            Self.logger.debug("Starting stream watch: \(key)")

            let asyncStream = stream()
            Self.logger.info("✅ Created stream for: \(key), starting iteration")
            for await value in asyncStream {
                guard !Task.isCancelled else {
                    Self.logger.debug("Stream cancelled: \(key)")
                    break
                }
                Self.logger.info("📨 Stream \(key) received value, calling handler")
                await handler(value)
            }

            Self.logger.debug("Stream ended: \(key)")
            streamTasks.removeValue(forKey: key)
        }

        streamTasks[key] = task
    }

    /// Stop watching a specific stream
    public func stopStream(key: String) {
        streamTasks[key]?.cancel()
        streamTasks.removeValue(forKey: key)
        Self.logger.debug("Stopped stream: \(key)")
    }

    /// Stop all active streams
    public func stopAllStreams() {
        for (key, task) in streamTasks {
            task.cancel()
            Self.logger.debug("Stopped stream: \(key)")
        }
        streamTasks.removeAll()
    }
    
    // MARK: - WatchedResult Helpers
    
    /// Helper computed property to check if any WatchedResult is loading
    /// Subclasses can override this to include their specific WatchedResults
    open var isWatchedDataLoading: Bool {
        false
    }
    
    /// Helper computed property to check if any WatchedResult has an error
    /// Subclasses can override this to include their specific WatchedResults
    open var watchedDataError: Error? {
        nil
    }
    
    /// Helper method to retry all failed WatchedResults
    /// Subclasses should override this to retry their specific WatchedResults
    open func retryFailedWatches() async {
        // Override in subclasses to retry specific WatchedResults
    }
}

// MARK: - Common ViewModel States

/// Common states that many ViewModels share
public enum CommonViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(ViewModelError)
    case empty

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var hasError: Bool {
        if case .error = self { return true }
        return false
    }

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
