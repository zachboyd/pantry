# Permission Pattern Documentation

## Overview

The Jeeves app uses a reactive permission system that automatically updates UI when permissions change in the GraphQL cache. This document explains the pattern for implementing permission-based UI in ViewModels and Views.

## Architecture

### 1. PermissionService (Backend Integration)
- Extracts permissions from GraphQL User data
- Builds CASL Ability instances from permission rules
- Watches Apollo cache for permission updates
- `@Observable` to trigger updates when permissions change

### 2. PermissionProvider (Reactive Layer)
- Wraps PermissionService with a clean, reusable API
- `@Observable` class that ViewModels can observe
- Provides convenient permission check methods
- Automatically triggers view updates when permissions change

### 3. ViewModels (Business Logic)
- Receive PermissionProvider through dependency injection
- Call permission check methods directly (no caching needed)
- Methods are automatically reactive due to `@Observable` chain

### 4. Views (UI)
- Access permissions through ViewModel methods
- Automatically re-render when permissions change
- No direct access to permission system

## Implementation Guide

### Step 1: Add PermissionProvider to ViewModel Dependencies

```swift
public struct MyViewModelDependencies: Sendable {
    // ... other dependencies ...
    public let permissionProvider: PermissionProvider?
    
    public init(
        // ... other parameters ...
        permissionProvider: PermissionProvider? = nil
    ) {
        // ... initialization ...
        self.permissionProvider = permissionProvider
    }
}
```

### Step 2: Create Permission Check Methods in ViewModel

```swift
@Observable @MainActor
public final class MyViewModel: BaseViewModel<MyViewModel.State, MyViewModelDependencies> {
    
    /// Check if user can perform an action
    /// This is reactive and will automatically update when permissions change
    public func canEditItem(_ itemId: String) -> Bool {
        return dependencies.permissionProvider?.can(.update, .item) ?? false
    }
    
    /// Check if user can delete items
    public func canDeleteItem(_ itemId: String) -> Bool {
        return dependencies.permissionProvider?.can(.delete, .item) ?? false
    }
    
    // No need for:
    // - Permission caching
    // - Manual observation
    // - Update callbacks
    // The @Observable chain handles everything!
}
```

### Step 3: Use in Views

```swift
struct MyView: View {
    @State private var viewModel: MyViewModel?
    
    var body: some View {
        List {
            // Permission-based UI - automatically updates when permissions change
            if viewModel?.canEditItem(item.id) == true {
                Button("Edit") {
                    // Edit action
                }
            }
            
            if viewModel?.canDeleteItem(item.id) == true {
                Button("Delete") {
                    // Delete action
                }
            }
        }
    }
}
```

## How It Works

1. **Permission Update Flow**:
   - Backend updates user permissions
   - Apollo cache receives new User data with permissions
   - PermissionService's watcher detects the change
   - PermissionService updates its `currentAbility` (marked `@Observable`)
   - PermissionProvider's `currentAbility` getter returns the new value
   - ViewModels calling permission methods get new results
   - Views automatically re-render with new permission state

2. **Reactivity Chain**:
   ```
   Apollo Cache → PermissionService (@Observable) → PermissionProvider (@Observable) → ViewModel → View
   ```

3. **No Manual Work Required**:
   - No `withObservationTracking` needed
   - No permission caching in ViewModels
   - No manual refresh triggers
   - No callbacks or notifications

## Common Permission Checks

The PermissionProvider includes these common checks:

- `canManageMembers(in: householdId)` - Can manage household members
- `canManageHousehold(householdId)` - Can manage the household itself
- `canUpdateHousehold(householdId)` - Can update household details
- `canDeleteHousehold(householdId)` - Can delete the household
- `can(action, subject)` - Generic check for any action/subject

## Best Practices

1. **Always use PermissionProvider**: Don't access AuthService.currentAbility directly
2. **Keep checks simple**: Return boolean values from ViewModel methods
3. **Name methods clearly**: Use `can` prefix for permission methods
4. **Handle nil gracefully**: Return `false` when PermissionProvider is nil
5. **Log important checks**: Add logging for debugging permission issues

## Testing

When testing ViewModels with permissions:

```swift
// Create a mock PermissionProvider
let mockProvider = MockPermissionProvider()
mockProvider.setPermission(.manage, .householdMember, allowed: true)

// Inject into ViewModel
let dependencies = MyViewModelDependencies(
    // ... other dependencies ...
    permissionProvider: mockProvider
)

let viewModel = MyViewModel(dependencies: dependencies)

// Test permission-based behavior
XCTAssertTrue(viewModel.canManageMembers(for: "household123"))
```

## Migration from Old Pattern

If you have ViewModels using the old pattern with manual observation:

1. Remove permission caching from State
2. Remove `observePermissionChanges()` methods
3. Remove `updatePermissionCache()` methods
4. Replace complex permission checks with simple PermissionProvider calls
5. Remove `withObservationTracking` code

## Example: SettingsViewModel

Before (complex, manual observation):
```swift
// State with cache
var canManageMembersCache: [String: Bool] = [:]

// Manual observation
private func observePermissionChanges() async {
    withObservationTracking {
        _ = dependencies.authService.currentAbility
    } onChange: {
        // Update caches...
    }
}
```

After (simple, automatic):
```swift
// Direct check - automatically reactive
public func canManageMembers(for householdId: String) -> Bool {
    return dependencies.permissionProvider?.canManageMembers(in: householdId) ?? false
}
```

## Troubleshooting

1. **Permissions not updating**: Check that PermissionService is subscribed to Apollo cache
2. **View not re-rendering**: Ensure ViewModel is `@Observable` and properly initialized
3. **Always false**: Check that PermissionProvider is injected in dependencies
4. **Logging**: Enable info-level logging for "Permissions" category to see checks