# Jeeves iOS Development Guide

This guide provides practical instructions for common development tasks in the Jeeves iOS app.

## Table of Contents

1. [Adding a New Feature](#adding-a-new-feature)
2. [Working with GraphQL](#working-with-graphql)
3. [Creating ViewModels](#creating-viewmodels)
4. [Adding New Services](#adding-new-services)
5. [Navigation and Routing](#navigation-and-routing)
6. [UI Components](#ui-components)
7. [Error Handling](#error-handling)
8. [Testing](#testing)
9. [Debugging](#debugging)

## Adding a New Feature

### Example: Adding a "Recipe" Feature

Let's walk through adding a complete feature from scratch:

#### 1. Define GraphQL Operations

Create `Sources/JeevesKit/GraphQL/Operations/RecipeOperations.graphql`:

```graphql
query GetRecipes($householdId: String!) {
  recipes(householdId: $householdId) {
    id
    name
    ingredients
    instructions
    prepTime
    cookTime
  }
}

mutation CreateRecipe($input: CreateRecipeInput!) {
  createRecipe(input: $input) {
    id
    name
  }
}
```

#### 2. Generate Types

```bash
./Scripts/generate-apollo-types.sh
```

This creates typed Swift code in `Sources/JeevesKit/GraphQL/Generated/`

#### 3. Create the Service

Create `Sources/JeevesKit/Services/RecipeService.swift`:

```swift
import Foundation

@MainActor
public final class RecipeService: RecipeServiceProtocol {
    private let graphQLService: GraphQLServiceProtocol
    private let authService: AuthServiceProtocol
    
    public init(
        graphQLService: GraphQLServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.graphQLService = graphQLService
        self.authService = authService
    }
    
    public func getRecipes(householdId: String) async throws -> [Recipe] {
        let query = JeevesGraphQL.GetRecipesQuery(householdId: householdId)
        let data = try await graphQLService.query(query)
        return data.recipes.map { mapToDomainModel($0) }
    }
    
    public func createRecipe(_ recipe: Recipe) async throws -> Recipe {
        let mutation = JeevesGraphQL.CreateRecipeMutation(
            input: JeevesGraphQL.CreateRecipeInput(
                name: recipe.name,
                // ... other fields
            )
        )
        let data = try await graphQLService.mutate(mutation)
        return mapToDomainModel(data.createRecipe)
    }
}
```

#### 4. Add to Service Factory

Update `Sources/JeevesKit/DI/ServiceFactory.swift`:

```swift
public static func createRecipeService(
    graphQLService: GraphQLServiceProtocol,
    authService: AuthServiceProtocol
) throws -> RecipeServiceProtocol {
    return RecipeService(
        graphQLService: graphQLService,
        authService: authService
    )
}
```

#### 5. Create ViewModel

Create `Sources/JeevesKit/ViewModels/Recipe/RecipeListViewModel.swift`:

```swift
import Foundation

@MainActor
@Observable
public final class RecipeListViewModel: BaseReactiveViewModel<RecipeListViewModel.State, RecipeListViewModel.Dependencies> {
    
    public struct State {
        var recipes: [Recipe] = []
        var searchText: String = ""
        var selectedRecipeId: String?
    }
    
    public struct Dependencies {
        let recipeService: RecipeServiceProtocol
        let householdService: HouseholdServiceProtocol
    }
    
    // MARK: - Computed Properties
    
    public var filteredRecipes: [Recipe] {
        guard !state.searchText.isEmpty else { return state.recipes }
        return state.recipes.filter { 
            $0.name.localizedCaseInsensitiveContains(state.searchText) 
        }
    }
    
    // MARK: - Actions
    
    public func loadRecipes() async {
        await performTask(loadingKey: "loadRecipes") {
            guard let householdId = await getCurrentHouseholdId() else {
                throw ViewModelError.householdNotFound
            }
            
            let recipes = try await dependencies.recipeService.getRecipes(
                householdId: householdId
            )
            
            updateState { state in
                state.recipes = recipes
            }
        }
    }
    
    public func createRecipe(name: String, ingredients: [String]) async {
        await performTask(loadingKey: "createRecipe") {
            // Implementation
        }
    }
}
```

#### 6. Add to ViewModelFactory

Update `Sources/JeevesKit/ViewModels/ViewModelFactory.swift`:

```swift
public func makeRecipeListViewModel() throws -> RecipeListViewModel {
    let recipeService = try container.getRecipeService()
    let householdService = try container.getHouseholdService()
    
    let dependencies = RecipeListViewModel.Dependencies(
        recipeService: recipeService,
        householdService: householdService
    )
    
    return RecipeListViewModel(
        dependencies: dependencies,
        initialState: RecipeListViewModel.State()
    )
}
```

#### 7. Create the View

Create `Sources/JeevesKit/Features/Recipe/RecipeListView.swift`:

```swift
import SwiftUI

public struct RecipeListView: View {
    @State private var viewModel: RecipeListViewModel
    
    public init(viewModel: RecipeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredRecipes) { recipe in
                    RecipeRowView(recipe: recipe)
                }
            }
            .searchable(text: $viewModel.state.searchText)
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        // Show add recipe sheet
                    }
                }
            }
            .task {
                await viewModel.loadRecipes()
            }
            .refreshable {
                await viewModel.loadRecipes()
            }
        }
    }
}
```

## Working with GraphQL

### Query Pattern

```swift
// 1. Define the query in .graphql file
// 2. Generate types
// 3. Use in service:

let query = JeevesGraphQL.YourQuery(param: value)
let data = try await graphQLService.query(query)
```

### Mutation Pattern

```swift
let mutation = JeevesGraphQL.YourMutation(
    input: JeevesGraphQL.YourInput(
        field1: value1,
        field2: value2
    )
)
let data = try await graphQLService.mutate(mutation)
```

### Handling GraphQL Nullables

```swift
// For optional fields in mutations:
description: description.map { GraphQLNullable<String>.some($0) } ?? .none
```

## Creating ViewModels

### Basic ViewModel Structure

```swift
@MainActor
@Observable
public final class YourViewModel: BaseReactiveViewModel<YourViewModel.State, YourViewModel.Dependencies> {
    
    // MARK: - State
    public struct State {
        var items: [Item] = []
        var isEditing: Bool = false
        // ... other state
    }
    
    // MARK: - Dependencies
    public struct Dependencies {
        let service1: Service1Protocol
        let service2: Service2Protocol
    }
    
    // MARK: - Computed Properties
    public var hasItems: Bool {
        !state.items.isEmpty
    }
    
    // MARK: - Lifecycle
    public override func onAppear() async {
        await super.onAppear()
        await loadData()
    }
    
    // MARK: - Actions
    public func loadData() async {
        await performTask(loadingKey: "loadData") {
            let data = try await dependencies.service1.getData()
            updateState { $0.items = data }
        }
    }
}
```

### Loading States

```swift
// Check if specific operation is loading
if loadingStates.isLoading(for: "saveData") {
    ProgressView()
}

// Check if any operation is loading
if showLoadingIndicator {
    LoadingOverlay()
}
```

### Error Handling

```swift
await performTask(loadingKey: "operation") {
    do {
        try await riskyOperation()
    } catch {
        // Error is automatically stored in lastError
        // and showingError is set to true
        throw ViewModelError.custom("Operation failed")
    }
}
```

## Adding New Services

### Service Protocol

```swift
// In ServiceProtocols.swift
@MainActor
public protocol YourServiceProtocol: Sendable {
    func getData() async throws -> [DataItem]
    func createItem(_ item: DataItem) async throws -> DataItem
    func updateItem(_ item: DataItem) async throws -> DataItem
    func deleteItem(id: String) async throws
}
```

### Service Implementation

```swift
@MainActor
public final class YourService: YourServiceProtocol {
    private let graphQLService: GraphQLServiceProtocol
    private let authService: AuthServiceProtocol
    
    // Add caching if needed
    private var cache: [DataItem]?
    private var lastCacheUpdate: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    public init(
        graphQLService: GraphQLServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.graphQLService = graphQLService
        self.authService = authService
    }
    
    // Implement protocol methods...
}
```

## Navigation and Routing

### Type-Safe Navigation

```swift
// In NavigationDestination.swift
public enum NavigationDestination: Hashable {
    case recipeDetail(recipeId: String)
    case recipeEdit(recipeId: String?)
    // ... other destinations
}

// In your view
NavigationLink(value: NavigationDestination.recipeDetail(recipeId: recipe.id)) {
    RecipeRowView(recipe: recipe)
}
.navigationDestination(for: NavigationDestination.self) { destination in
    switch destination {
    case .recipeDetail(let id):
        RecipeDetailView(recipeId: id)
    case .recipeEdit(let id):
        RecipeEditView(recipeId: id)
    }
}
```

## UI Components

### Shared Components

The app provides a set of shared UI components to ensure consistency across all screens. **Always use these components instead of creating custom implementations.**

### Button Components

Located in `Sources/JeevesKit/Shared/PrimaryButton.swift`:

#### PrimaryButton
Use for main actions (filled background, prominent style):
```swift
PrimaryButton(
    "Sign In",
    isLoading: isLoading,
    isDisabled: !isFormValid
) {
    // Action
}
```

#### SecondaryButton
Use for secondary actions (bordered style):
```swift
SecondaryButton("Cancel") {
    // Action
}
```

#### TextButton
Use for tertiary/text-only actions (minimal styling, link color):
```swift
TextButton("Forgot Password?") {
    // Action
}
```

### FormTextField Component

Located in `Sources/JeevesKit/Shared/FormTextField.swift`:

**Always use FormTextField instead of raw TextField or SecureField for consistency.**

#### Features
- Unified design with consistent styling
- Password visibility toggle for secure fields
- Real-time validation with error messages
- Focus state handling with visual feedback
- Full accessibility support

#### Convenience Methods

##### Email Input
```swift
FormTextField.email(
    text: $email,
    accessibilityIdentifier: "emailField"
)
```

##### Password Input
```swift
FormTextField.password(
    text: $password,
    validation: { $0.count >= 6 },
    errorMessage: "Password must be at least 6 characters"
)
```

##### Name Input
```swift
FormTextField.name(
    label: "First Name",
    placeholder: "Enter your first name",
    text: $firstName,
    textContentType: .givenName
)
```

#### Custom Fields
```swift
FormTextField(
    label: "Household Name",
    placeholder: "e.g., The Smith Family",
    text: $householdName,
    validation: { !$0.isEmpty },
    errorMessage: "Household name is required"
)
```

### Design Tokens

Always use design tokens for consistent styling:

```swift
// Colors
DesignTokens.Colors.Primary.base
DesignTokens.Colors.Text.primary
DesignTokens.Colors.Text.link
DesignTokens.Colors.Status.error

// Spacing
DesignTokens.Spacing.sm  // 8
DesignTokens.Spacing.md  // 16
DesignTokens.Spacing.lg  // 24
DesignTokens.Spacing.xl  // 32

// Typography
DesignTokens.Typography.Semantic.pageTitle()
DesignTokens.Typography.Semantic.sectionHeader()
DesignTokens.Typography.Semantic.body()
DesignTokens.Typography.Semantic.caption()

// Border Radius
DesignTokens.BorderRadius.sm  // 8
DesignTokens.BorderRadius.md  // 12
DesignTokens.BorderRadius.lg  // 16
```

### Accessibility

All shared components include proper accessibility support:

```swift
// FormTextField includes accessibility by default
FormTextField.email(
    text: $email,
    accessibilityIdentifier: AccessibilityUtilities.Identifier.emailField
)

// Buttons automatically handle accessibility
PrimaryButton("Sign In", isLoading: isLoading) {
    // Action is announced appropriately
}
```

## Error Handling

### Service Errors

```swift
public enum ServiceError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidData(String)
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .operationFailed(let message):
            return message
        }
    }
}
```

### ViewModel Errors

```swift
// Throw specific errors
throw ViewModelError.validationFailed([
    ValidationError(field: "name", message: "Name is required"),
    ValidationError(field: "email", message: "Invalid email format")
])

// Display in UI
.alert("Error", isPresented: $viewModel.showingError) {
    Button("OK") { viewModel.dismissError() }
} message: {
    Text(viewModel.errorMessage ?? "An error occurred")
}
```

## Testing

### Unit Test Structure

```swift
import XCTest
@testable import JeevesKit

final class RecipeServiceTests: XCTestCase {
    var sut: RecipeService!
    var mockGraphQLService: MockGraphQLService!
    var mockAuthService: MockAuthService!
    
    override func setUp() {
        super.setUp()
        mockGraphQLService = MockGraphQLService()
        mockAuthService = MockAuthService()
        sut = RecipeService(
            graphQLService: mockGraphQLService,
            authService: mockAuthService
        )
    }
    
    func testGetRecipes() async throws {
        // Given
        let expectedRecipes = [Recipe.mock]
        mockGraphQLService.queryResult = MockRecipeData(recipes: expectedRecipes)
        
        // When
        let recipes = try await sut.getRecipes(householdId: "123")
        
        // Then
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.name, expectedRecipes.first?.name)
    }
}
```

### Mock Services

```swift
class MockRecipeService: RecipeServiceProtocol {
    var recipes: [Recipe] = []
    var error: Error?
    
    func getRecipes(householdId: String) async throws -> [Recipe] {
        if let error = error {
            throw error
        }
        return recipes
    }
}
```

## Debugging

### Common Issues and Solutions

#### 1. "Value of type 'X' has no member 'Y'"

**Cause**: Missing method or property in dependency
**Solution**: Check protocol definition and implementation

#### 2. GraphQL Types Not Found

**Cause**: Types not generated or outdated
**Solution**: Run `./Scripts/generate-apollo-types.sh`

#### 3. Async Operations Not Updating UI

**Cause**: Not using @MainActor or missing state updates
**Solution**: Ensure ViewModel is @MainActor and use updateState()

#### 4. Navigation Not Working

**Cause**: Missing navigationDestination modifier
**Solution**: Add `.navigationDestination(for:)` to NavigationStack

### Debugging Tools

```swift
// Add debug logging
private static let logger = Logger(category: "RecipeService")

// Log operations
Self.logger.info("Loading recipes for household: \(householdId)")

// Check loading states
print("Loading states: \(viewModel.loadingStates.activeOperations)")

// Verify dependencies
print("Has auth service: \(authService != nil)")
```

### Console Logging

See [Troubleshooting Guide](TROUBLESHOOTING.md) for details on viewing logs.

## Best Practices

1. **Always use protocols** for services to enable testing
2. **Map GraphQL types to domain models** at service boundaries
3. **Use structured error handling** with specific error types
4. **Implement caching** in services for better performance
5. **Keep ViewModels focused** - one primary responsibility
6. **Use dependency injection** via ViewModelFactory
7. **Test edge cases** including error scenarios
8. **Document complex logic** with inline comments