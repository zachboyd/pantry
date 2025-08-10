# Jeeves App ViewModels

This directory contains all ViewModels for the Jeeves iOS app MVP, following the reactive patterns from the travel app with `@Observable` and `@MainActor` patterns.

## Architecture Overview

All ViewModels follow the BaseReactiveViewModel pattern with:
- **@Observable @MainActor**: For SwiftUI compatibility and thread safety
- **State Management**: Structured state with updateState() methods
- **Loading States**: Operation-specific loading management via LoadingStates class
- **Error Handling**: Comprehensive error handling with ViewModelError enum
- **Dependency Injection**: Clean dependencies pattern with dedicated dependency structs
- **Task Management**: Async task execution with proper cancellation and retry logic

## ViewModels

### Authentication
- **LoginViewModel**: Email/password login with validation
- **SignUpViewModel**: Account creation with enhanced validation (8+ chars, uppercase, lowercase, number)

### Onboarding
- **OnboardingViewModel**: Data-driven onboarding flow with flexible steps
- **OnboardingCoordinator**: Navigation and flow management

### Household Management
- **HouseholdListViewModel**: View and select households with search/filtering
- **HouseholdEditViewModel**: Create and edit households (create/edit modes)
- **HouseholdMembersViewModel**: Manage household members, roles, and invitations

### Tab ViewModels (MVP Placeholders)
- **JeevesTabViewModel**: Jeeves items management with categories, search, sorting
- **ChatTabViewModel**: Placeholder for future chat features
- **ListsTabViewModel**: Shopping lists management with item completion tracking

### Settings
- **SettingsViewModel**: User profile, household switching, notification settings

## Key Features

### State Management
- Selected household tracking across all ViewModels
- Full-screen loading states for async operations
- Comprehensive error states with recovery suggestions
- Form validation with field-specific error messages

### Loading Management
- Operation-specific loading states (save, delete, update, etc.)
- Loading state aggregation (isAnyLoading)
- Task cancellation and retry mechanisms
- Progress tracking for multi-step operations

### Error Handling
- ViewModelError enum with pantry-specific errors
- Localized error messages with recovery suggestions
- Error state management in ViewModels
- Graceful error recovery patterns

### Data Flow
- UserDefaults integration for persistent selections
- NotificationCenter for cross-app communication
- Reactive updates with @Observable pattern
- Clean separation between ViewModels and Services

## Dependencies

### ViewModelDependencies.swift
Defines dependency structs for each ViewModel with clean service injection, including PermissionProvider for reactive permission-based UI.

### ViewModelFactory.swift
SafeViewModelFactory provides type-safe ViewModel creation with dependency injection from DependencyContainer.

### Permission System
ViewModels integrate with the reactive permission system through PermissionProvider. See [Services/PERMISSION_PATTERN.md](../Services/PERMISSION_PATTERN.md) for implementation details.

## Usage Examples

### Creating ViewModels
```swift
@Environment(\.safeViewModelFactory) var factory

// In View
let viewModel = try factory.makeLoginViewModel()
let householdViewModel = try factory.makeHouseholdListViewModel()
```

### State Observation
```swift
@State private var viewModel: LoginViewModel

var body: some View {
    VStack {
        if viewModel.showLoadingIndicator {
            ProgressView()
        }
        // UI content
    }
    .alert("Error", isPresented: $viewModel.showingError) {
        Button("OK") { viewModel.dismissError() }
    } message: {
        Text(viewModel.errorMessage ?? "")
    }
}
```

### Lifecycle Management
```swift
.task {
    await viewModel.onAppear()
}
.onDisappear {
    Task {
        await viewModel.onDisappear()
    }
}
```

## Integration Points

### Services
All ViewModels integrate with services through DependencyContainer:
- AuthService: Authentication operations
- HouseholdService: Household CRUD operations  
- UserService: User profile management
- ItemService: Item operations
- ShoppingListService: Shopping list operations
- PermissionService: CASL-based permission management with reactive UI updates

### State Coordination
- Household selection persisted in UserDefaults
- Cross-ViewModel communication via NotificationCenter
- Reactive updates propagate automatically

### Error Recovery
- Network errors with retry mechanisms
- Validation errors with field-specific guidance
- State recovery after errors
- Graceful degradation for non-critical failures

## Future Enhancements

### Planned Features
- Real-time updates via WebSocket/GraphQL subscriptions
- Offline support with local caching
- Push notification integration
- Advanced search and filtering
- Bulk operations support

### Architecture Improvements
- Stream-based reactive updates
- Background sync capabilities
- Performance optimizations
- Memory management enhancements

## Testing

ViewModels are designed for easy testing with:
- Dependency injection for service mocking
- State-based testing patterns
- Async operation testing support
- Error condition simulation