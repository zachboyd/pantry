import Foundation
import SwiftUI

/// Factory for creating ViewModels with type-safe initialization
///
/// This factory provides a centralized place for creating ViewModels with proper dependency injection.
/// It ensures that all ViewModels receive their required services from the DependencyContainer,
/// following the MVVM architecture where ViewModels only have access to services.
///
/// ## Usage
/// ```swift
/// @Environment(\.safeViewModelFactory) var factory
///
/// // Create a ViewModel
/// let viewModel = try factory.makeLoginViewModel()
/// ```
///
/// ## Error Handling
/// All factory methods throw errors if required services are not available in the container.
/// This ensures fail-fast behavior and clear error messages during development.
@MainActor
public struct SafeViewModelFactory {
    // MARK: - Private Properties

    private let container: DependencyContainer
    private weak var appState: AppState?

    // MARK: - Initialization

    public init(container: DependencyContainer, appState: AppState? = nil) {
        self.container = container
        self.appState = appState
    }

    // MARK: - Authentication ViewModels

    /// Create LoginViewModel
    public func makeLoginViewModel() throws -> LoginViewModel {
        let authService = try container.getAuthService()
        let apolloClientService = try? container.getApolloClientService()

        let dependencies = AuthenticationDependencies(
            authService: authService,
            apolloClient: apolloClientService?.apollo,
        )

        return LoginViewModel(dependencies: dependencies)
    }

    /// Create SignUpViewModel
    public func makeSignUpViewModel() throws -> SignUpViewModel {
        let authService = try container.getAuthService()
        let apolloClientService = try? container.getApolloClientService()

        let dependencies = AuthenticationDependencies(
            authService: authService,
            apolloClient: apolloClientService?.apollo,
        )

        return SignUpViewModel(dependencies: dependencies)
    }

    // MARK: - Onboarding ViewModels

    /// Create OnboardingViewModel
    public func makeOnboardingViewModel() throws -> OnboardingViewModel {
        let authService = try container.getAuthService()
        let householdService = try container.getHouseholdService()
        let userService = try container.getUserService()

        let dependencies = OnboardingDependencies(
            authService: authService,
            householdService: householdService,
            userService: userService,
        )

        return OnboardingViewModel(dependencies: dependencies)
    }

    /// Create OnboardingCoordinator
    public func makeOnboardingCoordinator() -> OnboardingCoordinator {
        OnboardingCoordinator()
    }

    /// Create OnboardingContainerViewModel
    public func makeOnboardingContainerViewModel() throws -> OnboardingContainerViewModel {
        let authService = try container.getAuthService()
        let householdService = try container.getHouseholdService()
        let userService = try container.getUserService()

        let dependencies = OnboardingDependencies(
            authService: authService,
            householdService: householdService,
            userService: userService,
        )

        return OnboardingContainerViewModel(dependencies: dependencies)
    }

    /// Create UserInfoViewModel
    public func makeUserInfoViewModel(currentUser: User?) throws -> UserInfoViewModel {
        let userService = try container.getUserService()
        let authService = try container.getAuthService()

        let dependencies = UserInfoDependencies(
            userService: userService,
            authService: authService,
        )

        return UserInfoViewModel(dependencies: dependencies, currentUser: currentUser)
    }

    /// Create HouseholdCreationViewModel
    public func makeHouseholdCreationViewModel() throws -> HouseholdCreationViewModel {
        let householdService = try container.getHouseholdService()
        let authService = try container.getAuthService()

        let dependencies = HouseholdCreationDependencies(
            householdService: householdService,
            authService: authService,
        )

        return HouseholdCreationViewModel(dependencies: dependencies)
    }

    /// Create HouseholdJoinViewModel
    public func makeHouseholdJoinViewModel() throws -> HouseholdJoinViewModel {
        let householdService = try container.getHouseholdService()

        let dependencies = HouseholdJoinDependencies(
            householdService: householdService,
        )

        return HouseholdJoinViewModel(dependencies: dependencies)
    }

    // MARK: - Household ViewModels

    /// Create HouseholdListViewModel
    public func makeHouseholdListViewModel() throws -> HouseholdListViewModel {
        let householdService = try container.getHouseholdService()
        let authService = try container.getAuthService()
        let userService = try container.getUserService()

        let dependencies = HouseholdListDependencies(
            householdService: householdService,
            authService: authService,
            userService: userService,
        )

        return HouseholdListViewModel(dependencies: dependencies)
    }

    /// Create HouseholdEditViewModel
    public func makeHouseholdEditViewModel(
        householdId: String? = nil,
        mode: HouseholdEditMode = .create,
        isReadOnly: Bool = false,
    ) throws -> HouseholdEditViewModel {
        let householdService = try container.getHouseholdService()
        let authService = try container.getAuthService()
        let permissionService = try container.getPermissionService()

        let dependencies = HouseholdEditDependencies(
            householdService: householdService,
            authService: authService,
            permissionService: permissionService,
        )

        return HouseholdEditViewModel(
            dependencies: dependencies,
            householdId: householdId,
            mode: mode,
            isReadOnly: isReadOnly,
        )
    }

    /// Create HouseholdMembersViewModel
    public func makeHouseholdMembersViewModel(householdId: String) throws -> HouseholdMembersViewModel {
        let householdService = try container.getHouseholdService()
        let userService = try container.getUserService()
        let authService = try container.getAuthService()
        let permissionService = try container.getPermissionService()

        let dependencies = HouseholdMembersDependencies(
            householdService: householdService,
            userService: userService,
            authService: authService,
            permissionService: permissionService,
        )

        return HouseholdMembersViewModel(dependencies: dependencies, householdId: householdId)
    }

    /// Create HouseholdViewModel
    public func makeHouseholdViewModel() throws -> HouseholdViewModel {
        let householdService = try container.getHouseholdService()
        let authService = try container.getAuthService()

        return HouseholdViewModel(
            householdService: householdService,
            authService: authService,
        )
    }

    // MARK: - Tab ViewModels

    /// Create JeevesTabViewModel
    public func makeJeevesTabViewModel() throws -> JeevesTabViewModel {
        let itemService = try container.getItemService()
        let householdService = try container.getHouseholdService()

        let dependencies = JeevesTabDependencies(
            itemService: itemService,
            householdService: householdService,
        )

        return JeevesTabViewModel(dependencies: dependencies)
    }

    /// Create ChatTabViewModel
    public func makeChatTabViewModel() throws -> ChatTabViewModel {
        let householdService = try container.getHouseholdService()
        let userService = try container.getUserService()

        let dependencies = ChatTabDependencies(
            householdService: householdService,
            userService: userService,
        )

        return ChatTabViewModel(dependencies: dependencies)
    }

    /// Create ListsTabViewModel
    public func makeListsTabViewModel() throws -> ListsTabViewModel {
        let shoppingListService = try container.getShoppingListService()
        let householdService = try container.getHouseholdService()

        let dependencies = ListsTabDependencies(
            shoppingListService: shoppingListService,
            householdService: householdService,
        )

        return ListsTabViewModel(dependencies: dependencies)
    }

    // MARK: - Settings ViewModels

    /// Create UserSettingsViewModel
    public func makeUserSettingsViewModel() throws -> UserSettingsViewModel {
        let authService = try container.getAuthService()
        let userService = try container.getUserService()
        let userPreferencesService = try container.getUserPreferencesService()
        let householdService = try container.getHouseholdService()
        let permissionService = try container.getPermissionService()

        let dependencies = UserSettingsDependencies(
            authService: authService,
            userService: userService,
            userPreferencesService: userPreferencesService,
            householdService: householdService,
            permissionService: permissionService,
        )

        return UserSettingsViewModel(dependencies: dependencies)
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for SafeViewModelFactory
public struct SafeViewModelFactoryKey: EnvironmentKey {
    public static let defaultValue: SafeViewModelFactory? = nil
}

public extension EnvironmentValues {
    var safeViewModelFactory: SafeViewModelFactory? {
        get { self[SafeViewModelFactoryKey.self] }
        set { self[SafeViewModelFactoryKey.self] = newValue }
    }
}

// MARK: - Supporting Types

/// Edit modes for household editing
public enum HouseholdEditMode: Sendable, CustomStringConvertible {
    case create
    case edit

    public var description: String {
        switch self {
        case .create:
            "create"
        case .edit:
            "edit"
        }
    }
}
