import SwiftUI

// MARK: - Error Alert View Modifier

/// A view modifier that presents error alerts with consistent styling and behavior
public struct ErrorAlertModifier: ViewModifier {
    @Binding var error: ViewModelError?
    let onDismiss: (() -> Void)?

    public func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { _ in error = nil }
                ),
                presenting: error
            ) { _ in
                Button("OK") {
                    error = nil
                    onDismiss?()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.errorDescription ?? "An unexpected error occurred")

                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Presents an error alert when an error occurs
    /// - Parameters:
    ///   - error: Binding to the optional error that triggers the alert
    ///   - onDismiss: Optional closure called when the alert is dismissed
    func errorAlert(
        error: Binding<ViewModelError?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(error: error, onDismiss: onDismiss))
    }
}

// MARK: - Error Boundary View

/// A view that provides error boundary functionality for async operations
public struct ErrorBoundary<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var error: ViewModelError?

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .errorAlert(error: $error)
    }
}

// MARK: - Error Handler Environment Key

private struct ErrorHandlerKey: EnvironmentKey {
    static let defaultValue = ErrorHandler { _ in }
}

public extension EnvironmentValues {
    var errorHandler: ErrorHandler {
        get { self[ErrorHandlerKey.self] }
        set { self[ErrorHandlerKey.self] = newValue }
    }
}

// MARK: - Error Handler

/// A handler for propagating errors up the view hierarchy
public struct ErrorHandler: Sendable {
    private let handler: @Sendable (ViewModelError) -> Void

    public init(handler: @escaping @Sendable (ViewModelError) -> Void) {
        self.handler = handler
    }

    public func handle(_ error: ViewModelError) {
        handler(error)
    }

    public func handle(_ error: Error) {
        let viewModelError: ViewModelError

        switch error {
        case let vmError as ViewModelError:
            viewModelError = vmError
        case let validationError as ValidationError:
            viewModelError = .validationFailed([validationError])
        default:
            viewModelError = .unknown(error.localizedDescription)
        }

        handler(viewModelError)
    }
}

// MARK: - Async Error Handling Extension

public extension View {
    /// Wraps an async operation with error handling
    /// - Parameters:
    ///   - priority: Task priority
    ///   - errorHandler: Error handler to use
    ///   - operation: The async operation to perform
    func task<T>(
        priority: TaskPriority = .userInitiated,
        errorHandler: ErrorHandler,
        _ operation: @escaping @Sendable () async throws -> T
    ) -> some View {
        task(priority: priority) {
            do {
                _ = try await operation()
            } catch {
                await MainActor.run {
                    errorHandler.handle(error)
                }
            }
        }
    }
}
