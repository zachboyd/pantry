@preconcurrency import Apollo
import Foundation
import Observation

// MARK: - SignUpViewModel

/// ViewModel for managing sign up form and account creation
@Observable @MainActor
public final class SignUpViewModel: BaseReactiveViewModel<SignUpViewModel.State, AuthenticationDependencies> {
    private static let logger = Logger.auth

    // MARK: - State

    public struct State: Sendable {
        var email = ""
        var password = ""
        var confirmPassword = ""
        var acceptTerms = false
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?

        // Form validation
        var emailError: String?
        var passwordError: String?
        var confirmPasswordError: String?
        var termsError: String?
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

    public var confirmPassword: String {
        get { state.confirmPassword }
        set { updateState { $0.confirmPassword = newValue } }
    }

    public var acceptTerms: Bool {
        get { state.acceptTerms }
        set { updateState { $0.acceptTerms = newValue } }
    }

    public var isSignUpEnabled: Bool {
        !state.email.isEmpty &&
            !state.password.isEmpty &&
            !state.confirmPassword.isEmpty &&
            state.password == state.confirmPassword &&
            state.acceptTerms &&
            !loadingStates.isLoading(.initial) &&
            state.emailError == nil &&
            state.passwordError == nil &&
            state.confirmPasswordError == nil &&
            state.termsError == nil
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

    public var confirmPasswordError: String? {
        state.confirmPasswordError
    }

    public var termsError: String? {
        state.termsError
    }

    // MARK: - Initialization

    public required init(dependencies: AuthenticationDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("📝 SignUpViewModel initialized")
    }

    public required init(dependencies: AuthenticationDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
    }

    // MARK: - Public Methods

    /// Sign up with email and password
    public func signUp() {
        executeTask(.initial) {
            await self.performSignUp()
        }
    }

    /// Clear form data
    public func clearForm() {
        updateState {
            $0.email = ""
            $0.password = ""
            $0.confirmPassword = ""
            $0.acceptTerms = false
            $0.viewState = .idle
            $0.showingError = false
            $0.errorMessage = nil
            $0.emailError = nil
            $0.passwordError = nil
            $0.confirmPasswordError = nil
            $0.termsError = nil
        }
        clearError()
    }

    /// Clear validation errors
    public func clearValidationErrors() {
        updateState {
            $0.emailError = nil
            $0.passwordError = nil
            $0.confirmPasswordError = nil
            $0.termsError = nil
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

        if state.password.count < PasswordConstants.minimumLength {
            updateState { $0.passwordError = PasswordConstants.tooShortError }
            return
        }

        // Check for at least one uppercase letter
        if !state.password.contains(where: { $0.isUppercase }) {
            updateState { $0.passwordError = L("validation.password_uppercase_required") }
            return
        }

        // Check for at least one lowercase letter
        if !state.password.contains(where: { $0.isLowercase }) {
            updateState { $0.passwordError = L("validation.password_lowercase_required") }
            return
        }

        // Check for at least one number
        if !state.password.contains(where: { $0.isNumber }) {
            updateState { $0.passwordError = L("validation.password_number_required") }
            return
        }
    }

    /// Validate password confirmation
    public func validateConfirmPassword() {
        updateState { $0.confirmPasswordError = nil }

        guard !state.confirmPassword.isEmpty else {
            updateState { $0.confirmPasswordError = L("validation.confirm_password_required") }
            return
        }

        if state.password != state.confirmPassword {
            updateState { $0.confirmPasswordError = PasswordConstants.mismatchError }
        }
    }

    /// Validate terms acceptance
    public func validateTerms() {
        updateState { $0.termsError = nil }

        if !state.acceptTerms {
            updateState { $0.termsError = L("validation.terms_required") }
        }
    }

    /// Validate all fields for sign up
    public func validateForm() -> Bool {
        validateEmail()
        validatePassword()
        validateConfirmPassword()
        validateTerms()

        return state.emailError == nil &&
            state.passwordError == nil &&
            state.confirmPasswordError == nil &&
            state.termsError == nil
    }

    // MARK: - Private Methods

    private func performSignUp() async {
        Self.logger.info("📝 Starting sign up process")

        guard validateForm() else {
            Self.logger.warning("⚠️ Sign up form validation failed")
            return
        }

        updateState { $0.viewState = .loading }

        do {
            // Step 1: Create account with Better-Auth
            let userId = try await dependencies.authService.signUp(email: state.email, password: state.password)
            Self.logger.info("✅ Account creation successful for userId: \(userId)")

            // Step 2: Success
            updateState { $0.viewState = .loaded }
            Self.logger.info("🎉 Sign up process completed successfully")

        } catch {
            Self.logger.error("❌ Sign up failed: \(error)")
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
        Self.logger.debug("👁️ SignUpViewModel appeared")
        await super.onAppear()
    }

    override public func onDisappear() async {
        Self.logger.debug("👁️ SignUpViewModel disappeared")
        await super.onDisappear()
    }

    override public func refresh() async {
        Self.logger.debug("🔄 SignUpViewModel refresh")
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
