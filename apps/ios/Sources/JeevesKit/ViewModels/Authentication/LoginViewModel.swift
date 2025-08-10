@preconcurrency import Apollo
import Foundation
import Observation

// MARK: - LoginViewModel

/// ViewModel for managing login form and authentication
@Observable @MainActor
public final class LoginViewModel: BaseReactiveViewModel<LoginViewModel.State, AuthenticationDependencies> {
    private static let logger = Logger.auth

    // MARK: - State

    public struct State: Sendable {
        var email = ""
        var password = ""
        var rememberMe = true
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?

        // Form validation
        var emailError: String?
        var passwordError: String?
    }

    // MARK: - Computed Properties

    public var email: String {
        get { state.email }
        set { updateState { $0.email = newValue } }
    }

    public var password: String {
        get { state.password }
        set { updateState { $0.password = newValue } }
    }

    public var rememberMe: Bool {
        get { state.rememberMe }
        set { updateState { $0.rememberMe = newValue } }
    }

    public var isSignInEnabled: Bool {
        !state.email.isEmpty &&
            !state.password.isEmpty &&
            !loadingStates.isLoading(.initial) &&
            state.emailError == nil &&
            state.passwordError == nil
    }

    public var showLoadingIndicator: Bool {
        loadingStates.isAnyLoading
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    public var showingError: Bool {
        state.showingError
    }

    public var emailError: String? {
        state.emailError
    }

    public var passwordError: String? {
        state.passwordError
    }

    // MARK: - Initialization

    public required init(dependencies: AuthenticationDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("🔐 LoginViewModel initialized")
    }

    public required init(dependencies: AuthenticationDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Public Methods

    /// Sign in with email and password
    public func signIn() {
        executeTask(.initial) {
            await self.performSignIn()
        }
    }

    /// Clear form data
    public func clearForm() {
        updateState {
            $0.email = ""
            $0.password = ""
            $0.rememberMe = true
            $0.viewState = .idle
            $0.showingError = false
            $0.errorMessage = nil
            $0.emailError = nil
            $0.passwordError = nil
        }
        clearError()
    }

    /// Clear validation errors
    public func clearValidationErrors() {
        updateState {
            $0.emailError = nil
            $0.passwordError = nil
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }

    /// Dismiss error
    public func dismissError() {
        updateState {
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }

    /// Validate email format
    public func validateEmail() {
        updateState { $0.emailError = nil }

        guard !state.email.isEmpty else {
            updateState { $0.emailError = L("validation.email_required") }
            return
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: state.email) {
            updateState { $0.emailError = L("auth.validation.invalid_email") }
        }
    }

    /// Validate password
    public func validatePassword() {
        updateState { $0.passwordError = nil }

        guard !state.password.isEmpty else {
            updateState { $0.passwordError = L("validation.password_required") }
            return
        }

        if state.password.count < 6 {
            updateState { $0.passwordError = L("auth.validation.password_short") }
        }
    }

    /// Validate all fields for sign in
    public func validateForm() -> Bool {
        validateEmail()
        validatePassword()
        return state.emailError == nil && state.passwordError == nil
    }

    // MARK: - Private Methods

    private func performSignIn() async {
        Self.logger.info("🔐 Starting sign in process")

        guard validateForm() else {
            Self.logger.warning("⚠️ Sign in form validation failed")
            return
        }

        updateState { $0.viewState = .loading }

        do {
            // Step 1: Authenticate with Better-Auth
            let userId = try await dependencies.authService.signIn(email: state.email, password: state.password)
            Self.logger.info("✅ Authentication successful for userId: \(userId)")

            // Step 2: Success
            updateState { $0.viewState = .loaded }
            Self.logger.info("🎉 Sign in process completed successfully")

        } catch {
            Self.logger.error("❌ Sign in failed: \(error)")
            let errorMessage = (error as? AuthServiceError)?.localizedMessage() ?? error.localizedDescription
            updateState {
                $0.viewState = .error(ViewModelError.operationFailed(errorMessage))
                $0.showingError = true
                $0.errorMessage = errorMessage
            }
        }
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ LoginViewModel appeared")
        await super.onAppear()
    }

    override public func onDisappear() async {
        Self.logger.debug("👁️ LoginViewModel disappeared")
        await super.onDisappear()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 LoginViewModel refresh")
        clearForm()
        await super.refresh()
    }

    // MARK: - Error Handling Override

    override public func handleError(_ error: Error) {
        super.handleError(error)

        let errorMessage = error.localizedDescription
        updateState {
            $0.showingError = true
            $0.errorMessage = errorMessage
            $0.viewState = .error(currentError ?? .unknown(errorMessage))
        }
    }
}
