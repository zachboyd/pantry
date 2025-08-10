# Error Handling Guide

This guide documents the error handling patterns used in the Jeeves iOS app.

## Overview

The app uses a comprehensive error handling system based on:
1. `ViewModelError` enum for standardized error types
2. `BaseReactiveViewModel` for automatic error management
3. View modifiers for consistent error presentation

## Error Handling Patterns

### Pattern 1: Using ErrorAlert Modifier (Recommended for Simple Views)

For views with simple error handling needs, use the `errorAlert` modifier:

```swift
struct MyView: View {
    @State private var viewModel = MyViewModel()
    
    var body: some View {
        // View content
        .errorAlert(error: $viewModel.currentError)
    }
}

// ViewModel
@Observable
final class MyViewModel {
    var currentError: ViewModelError?
    
    func performOperation() async {
        do {
            // Async operation
        } catch {
            currentError = .operationFailed("Operation failed")
        }
    }
}
```

### Pattern 2: ViewModels Extending BaseReactiveViewModel

For complex views with multiple async operations:

```swift
@Observable @MainActor
public final class MyTabViewModel: BaseReactiveViewModel<MyTabViewModel.State, MyDependencies> {
    public struct State {
        var showingError = false
        var errorMessage: String?
        var viewState: CommonViewState = .idle
    }
    
    override public func handleError(_ error: Error) {
        super.handleError(error)
        let errorMessage = error.localizedDescription
        updateState {
            $0.showingError = true
            $0.errorMessage = errorMessage
            $0.viewState = .error(currentError ?? .unknown(errorMessage))
        }
    }
    
    public func dismissError() {
        updateState {
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }
}
```

### Pattern 3: Using Error Boundaries

For views that need to catch all errors from child views:

```swift
struct MyContainerView: View {
    var body: some View {
        ErrorBoundary {
            // Child views that might throw errors
            MyComplexView()
        }
    }
}
```

## Error Types

The `ViewModelError` enum provides these error types:

- `networkUnavailable` - No internet connection
- `unauthorized` - User needs to sign in again
- `forbidden` - Insufficient permissions
- `notFound` - Resource not found
- `validationFailed([ValidationError])` - Form validation errors
- `operationFailed(String)` - Generic operation failure
- `repositoryError(String)` - Data layer errors
- `householdNotFound` - Household-specific error
- `itemNotFound` - Item-specific error
- `memberNotFound` - Member-specific error
- `insufficientPermissions` - Permission error
- `storageError(String)` - Storage/persistence error
- `unknown(String)` - Unexpected errors

## Implementation Checklist

When implementing error handling in a view:

1. ✅ Ensure ViewModel has `currentError: ViewModelError?` property
2. ✅ Add `.errorAlert(error: $viewModel.currentError)` to the view
3. ✅ Handle errors in async operations using do-catch blocks
4. ✅ Convert generic errors to ViewModelError types
5. ✅ For ViewModels extending BaseReactiveViewModel:
   - Override `handleError(_:)` method
   - Implement `dismissError()` method
   - Update state with error information

## Examples from the Codebase

### UserProfileView
- Uses simple error alert pattern
- Converts errors to ViewModelError in catch blocks

### JeevesTabView
- Extends BaseReactiveViewModel
- Manages error state in ViewModel
- Custom alert presentation

### SignInView
- Uses string-based error alerts
- Direct error message display

## Best Practices

1. **Always handle errors** - Never ignore errors in async operations
2. **Provide context** - Use specific error messages that help users understand what went wrong
3. **Suggest recovery** - ViewModelError includes recovery suggestions
4. **Log errors** - Always log errors for debugging
5. **Test error scenarios** - Include error cases in your testing