@preconcurrency import Apollo
import Foundation
import SwiftUI

// MARK: - ViewModel Dependencies

/// Dependencies required by ViewModels
public struct ViewModelDependencies {
    public let authService: AuthServiceProtocol
    public let householdService: HouseholdServiceProtocol
    public let userService: UserServiceProtocol
    public let userPreferencesService: UserPreferencesServiceProtocol
    public let pantryItemService: PantryItemServiceProtocol
    public let shoppingListService: ShoppingListServiceProtocol
    public let recipeService: RecipeServiceProtocol
    public let notificationService: NotificationServiceProtocol

    public init(
        authService: AuthServiceProtocol,
        householdService: HouseholdServiceProtocol,
        userService: UserServiceProtocol,
        userPreferencesService: UserPreferencesServiceProtocol,
        pantryItemService: PantryItemServiceProtocol,
        shoppingListService: ShoppingListServiceProtocol,
        recipeService: RecipeServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.authService = authService
        self.householdService = householdService
        self.userService = userService
        self.userPreferencesService = userPreferencesService
        self.pantryItemService = pantryItemService
        self.shoppingListService = shoppingListService
        self.recipeService = recipeService
        self.notificationService = notificationService
    }
}

// MARK: - Specific ViewModel Dependencies

/// Dependencies for AuthenticationViewModel
public struct AuthenticationDependencies: Sendable {
    public let authService: AuthServiceProtocol
    public let apolloClient: ApolloClient?

    public init(authService: AuthServiceProtocol, apolloClient: ApolloClient? = nil) {
        self.authService = authService
        self.apolloClient = apolloClient
    }
}


/// Dependencies for OnboardingViewModel
public struct OnboardingDependencies: Sendable {
    public let authService: AuthServiceProtocol
    public let householdService: HouseholdServiceProtocol
    public let userService: UserServiceProtocol

    public init(
        authService: AuthServiceProtocol,
        householdService: HouseholdServiceProtocol,
        userService: UserServiceProtocol
    ) {
        self.authService = authService
        self.householdService = householdService
        self.userService = userService
    }
}

/// Dependencies for HouseholdListViewModel
public struct HouseholdListDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol
    public let authService: AuthServiceProtocol
    public let userService: UserServiceProtocol

    public init(
        householdService: HouseholdServiceProtocol,
        authService: AuthServiceProtocol,
        userService: UserServiceProtocol
    ) {
        self.householdService = householdService
        self.authService = authService
        self.userService = userService
    }
}

/// Dependencies for HouseholdEditViewModel
public struct HouseholdEditDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol
    public let authService: AuthServiceProtocol

    public init(
        householdService: HouseholdServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.householdService = householdService
        self.authService = authService
    }
}

/// Dependencies for HouseholdMembersViewModel
public struct HouseholdMembersDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol
    public let userService: UserServiceProtocol
    public let authService: AuthServiceProtocol

    public init(
        householdService: HouseholdServiceProtocol,
        userService: UserServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.householdService = householdService
        self.userService = userService
        self.authService = authService
    }
}

/// Dependencies for SettingsViewModel
public struct SettingsDependencies: Sendable {
    public let authService: AuthServiceProtocol
    public let userService: UserServiceProtocol
    public let userPreferencesService: UserPreferencesServiceProtocol
    public let householdService: HouseholdServiceProtocol

    public init(
        authService: AuthServiceProtocol,
        userService: UserServiceProtocol,
        userPreferencesService: UserPreferencesServiceProtocol,
        householdService: HouseholdServiceProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.userPreferencesService = userPreferencesService
        self.householdService = householdService
    }
}

/// Dependencies for PantryTabViewModel
public struct PantryTabDependencies: Sendable {
    public let pantryItemService: PantryItemServiceProtocol
    public let householdService: HouseholdServiceProtocol

    public init(
        pantryItemService: PantryItemServiceProtocol,
        householdService: HouseholdServiceProtocol
    ) {
        self.pantryItemService = pantryItemService
        self.householdService = householdService
    }
}

/// Dependencies for ChatTabViewModel
public struct ChatTabDependencies: Sendable {
    public let householdService: HouseholdServiceProtocol
    public let userService: UserServiceProtocol

    public init(
        householdService: HouseholdServiceProtocol,
        userService: UserServiceProtocol
    ) {
        self.householdService = householdService
        self.userService = userService
    }
}

/// Dependencies for ListsTabViewModel
public struct ListsTabDependencies: Sendable {
    public let shoppingListService: ShoppingListServiceProtocol
    public let householdService: HouseholdServiceProtocol

    public init(
        shoppingListService: ShoppingListServiceProtocol,
        householdService: HouseholdServiceProtocol
    ) {
        self.shoppingListService = shoppingListService
        self.householdService = householdService
    }
}

// MARK: - Environment Keys for ViewModels

/// Environment key for ViewModel dependencies
private struct ViewModelDependenciesKey: EnvironmentKey {
    static var defaultValue: ViewModelDependencies {
        fatalError("ViewModelDependencies defaultValue should not be used directly. Use DependencyContainer injection instead.")
    }
}

public extension EnvironmentValues {
    /// Access ViewModel dependencies from environment
    var viewModelDependencies: ViewModelDependencies {
        get { self[ViewModelDependenciesKey.self] }
        set { self[ViewModelDependenciesKey.self] = newValue }
    }
}

// MARK: - SwiftUI Integration

public extension View {
    /// Setup ViewModel dependencies in the environment
    func withViewModelDependencies(_ dependencies: ViewModelDependencies) -> some View {
        environment(\.viewModelDependencies, dependencies)
    }
}
