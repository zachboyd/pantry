# Pantry iOS App - Claude Instructions

## Project Overview
This is an iOS/iPadOS-only project. The app is built using SwiftUI and targets iOS 18+.

## Important Notes

### Platform Target
- **iOS/iPadOS ONLY** - This project does NOT support macOS, tvOS, watchOS, or visionOS
- Always use iOS-specific build commands and simulators
- The Package.swift explicitly targets `.iOS(.v18)`

### Build Commands
✅ **ONLY use xcodebuild for iOS builds:**
```bash
# Build for iOS Simulator
xcodebuild -scheme Pantry -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build the library target
xcodebuild -scheme PantryKit -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run on simulator
xcodebuild -scheme Pantry -destination 'platform=iOS Simulator,name=iPhone 16 Pro' run
```

❌ **NEVER use these commands:**
- `swift build` - This ALWAYS tries to build for macOS, even with --arch flags
- `swift build --arch arm64` - Still builds for macOS, not iOS
- `swift test` - Runs tests for macOS
- Any macOS, tvOS, or watchOS destinations

⚠️ **CRITICAL: This is an iOS-only project. The swift command-line tools will always default to macOS builds. You MUST use xcodebuild with iOS destinations for ALL builds and tests.**

### GraphQL Integration
- The app uses Apollo iOS for GraphQL
- Schema file: `Sources/PantryKit/GraphQL/schema.graphqls` (note the .graphqls extension with 's')
- Operations are in `Sources/PantryKit/GraphQL/Operations/` (files with .graphql extension)
- Generated code is in `Sources/PantryKit/GraphQL/Generated/`
- **Field Name Mapping**: Swift models use camelCase versions of GraphQL snake_case fields:
  - `created_by` → `createdBy`
  - `user_id` → `userId`
  - `household_id` → `householdId`
  - `joined_at` → `joinedAt`
  - etc.

### Architecture Pattern (MVVM)

The app follows a strict MVVM (Model-View-ViewModel) architecture:

```
View → ViewModel → Services → GraphQL/Apollo → Backend
```

**Key Rules**:
1. **Views** should ONLY interact with ViewModels, never directly with Services or AppState
2. **ViewModels** handle all business logic and coordinate with Services
3. **Services** manage data operations and communicate with GraphQL through Apollo
4. **AppState** is only accessed by container views for app-wide coordination

**Example Patterns**:

```swift
// ❌ WRONG - View directly accessing AppState
struct MyView: View {
    @Environment(\.appState) private var appState
    
    var body: some View {
        Button("Sign Out") {
            await appState?.signOut()  // Don't do this!
        }
        
        if let household = appState?.currentHousehold {  // Don't do this!
            Text(household.name)
        }
    }
}

// ✅ CORRECT - View uses parameters and callbacks
struct MyView: View {
    let viewModel: MyViewModel
    let currentHousehold: Household?
    let onSignOut: () async -> Void
    let onSelectHousehold: (Household) -> Void
    
    var body: some View {
        Button("Sign Out") {
            await onSignOut()  // Use callback
        }
        
        if let household = currentHousehold {  // Use parameter
            Text(household.name)
        }
    }
}

// ✅ CORRECT - Container view passing data/callbacks
struct MainAppContainerView: View {
    @Environment(\.appState) private var appState  // Container can access
    
    var body: some View {
        MyView(
            viewModel: viewModel,
            currentHousehold: appState?.currentHousehold,  // Pass as parameter
            onSignOut: {
                await appState?.signOut()  // Container handles state change
            },
            onSelectHousehold: { household in
                appState?.selectHousehold(household)  // Container handles state change
            }
        )
    }
}
```

**Container Views Exception**:
Only container views may access AppState to coordinate app-wide state:
- `PantryKit.swift` (AppRootContentView)
- `MainAppContainerView.swift`
- `AuthenticationContainerView.swift`
- `OnboardingContainerView.swift`

Container views responsibilities:
- Coordinate major app state transitions
- Pass data as parameters to child views (e.g., currentHousehold)
- Pass callbacks to child views for state modifications (e.g., onSelectHousehold, onSignOut)
- Handle navigation between app phases

### Service Architecture
- All services require real GraphQL backend - NO mock data in production
- UserService and HydrationService are GraphQL-only (no fallbacks)
- Apollo client is a required dependency for these services
- Services are injected into ViewModels through the dependency injection system
- **String Trimming**: Services automatically trim whitespace from string inputs before GraphQL mutations using `.trimmed()` extension. ViewModels should NOT handle trimming - see `Services/TRIMMING_IMPLEMENTATION_NOTE.md`

### ViewModels and Dependency Injection

**ViewModel Creation**:
- ViewModels are created through `SafeViewModelFactory` (available via `@Environment(\.safeViewModelFactory)`)
- Each ViewModel has specific dependencies defined in `ViewModelDependencies.swift`
- ViewModels extend `BaseReactiveViewModel` which provides common functionality

**Example ViewModel Usage**:
```swift
struct MyView: View {
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: MyViewModel?
    
    var body: some View {
        // View content
    }
    .task {
        viewModel = try? factory.makeMyViewModel()
        await viewModel?.onAppear()
    }
}
```

**Service Access Pattern**:
- ViewModels receive services through their dependencies
- Services handle all GraphQL operations through Apollo
- ViewModels NEVER directly access Apollo or make GraphQL queries
- AppState is NOT passed to ViewModels - use callbacks for state coordination


### Common Architecture Patterns

**Tab Views Pattern**:
- Tab views receive `currentHousehold` and `onSelectHousehold` as parameters from MainAppContainerView
- Tab views do NOT access AppState directly
- Each tab view has its own ViewModel for business logic

**Household Selection Pattern**:
- HouseholdSwitcherView receives `currentHouseholdId` and `onSelectHousehold` callback
- HouseholdHeaderView receives `household` and `onSelectHousehold` callback
- Selection changes are handled by container views through callbacks

**Authentication Pattern**:
- SignInView and SignUpView use `onSignInSuccess`/`onSignUpSuccess` callbacks
- AuthenticationContainerView handles the callbacks and updates AppState
- Sign out is handled through callbacks passed from container views

**Default Parameters**:
- Views should provide default parameter values for optional callbacks
- This allows views to be used in different contexts (e.g., previews, tests)
- Example: `onSelectHousehold: @escaping (Household) -> Void = { _ in }`

### Code Generation
```bash
# Generate Apollo types
./apollo-ios-cli generate

# Fetch latest schema from backend (outputs to Sources/PantryKit/GraphQL/schema.graphqls)
./apollo-ios-cli fetch-schema
```

### Testing
- Use iOS simulators for testing
- Available schemes: Pantry, PantryKit
- Test on various iOS devices and iPad for responsive design

### Swift 6 Compatibility
- Apollo iOS 1.x generates code that triggers Swift 6 concurrency warnings
- We use `@preconcurrency import Apollo` in our code to suppress these warnings
- The warning in generated files (like SchemaMetadata.graphql.swift) is expected and harmless
- Apollo iOS 2.0 will have full Swift 6 support
- DO NOT modify generated files to fix warnings - they will be overwritten

### Date Utilities
- **Centralized date conversion**: All GraphQL DateTime conversions use `DateUtilities.swift`
- Location: `Sources/PantryKit/Utilities/DateUtilities.swift`
- Thread-safe implementation using DispatchQueue for formatter access
- Key methods:
  - `dateFromGraphQL(_:)` - Convert GraphQL DateTime string to Date
  - `dateFromGraphQLOrNow(_:)` - Convert with fallback to current date
  - `graphQLStringFromDate(_:)` - Convert Date to GraphQL DateTime string
- Handles both dates with and without fractional seconds
- DO NOT create new ISO8601DateFormatter instances - always use DateUtilities
- All services (AuthService, UserService, HouseholdService, etc.) use these utilities

### Localization
- **NEVER hardcode user-facing strings** - Always use the localization system
- Use `L("key")` for all user-visible text
- Use `Lp("key", count)` for pluralized strings
- Localization is managed by `LocalizationManager` (same pattern as Travel app)
- **Exception**: Logger messages should NOT be localized - keep them in English
- Example usage:
  ```swift
  // ✅ Correct - localized strings
  Text(L("app.name"))
  Button(L("save")) { }
  .navigationTitle(L("settings.title"))
  TextField(L("auth.email.placeholder"), text: $email)
  
  // ❌ Wrong - hardcoded strings
  Text("Pantry")
  Button("Save") { }
  
  // ✅ Correct - logger messages in English (not localized)
  Logger.info("User tapped save button")
  ```
- Add new strings to `Sources/PantryKit/Localization/en.lproj/Localizable.strings`
- Follow the key naming convention: `feature.component.property` (e.g., `auth.button.signin`)
- See `Sources/PantryKit/Localization/README.md` for detailed guidelines

### UI Components
- **Button Components**: ALWAYS use the shared button components from `Sources/PantryKit/Shared/`
  - **PrimaryButton**: Use for main actions (filled background, prominent style)
    - Supports loading states with `isLoading` parameter
    - Supports disabled states with `isDisabled` parameter
    - Automatically handles visual feedback for disabled state (0.6 opacity)
  - **SecondaryButton**: Use for secondary actions (bordered style)
  - **TextButton**: Use for tertiary/text-only actions (minimal styling, uses link color)
- **DO NOT** create custom button styles - use the existing components for consistency
- Example usage:
  ```swift
  PrimaryButton(L("auth.button.signin"), isLoading: isLoading, isDisabled: !isFormValid) {
      // Action
  }
  ```

- **FormTextField Component**: ALWAYS use the shared FormTextField component from `Sources/PantryKit/Shared/FormTextField.swift`
  - **Features**:
    - Unified design with consistent styling across all inputs
    - Password visibility toggle for secure fields
    - Real-time validation with error messages
    - Focus state handling with visual feedback
    - Full accessibility support
  - **Convenience Methods**:
    - `FormTextField.email()` - Pre-configured for email input with validation
    - `FormTextField.password()` - Pre-configured for password input with visibility toggle
    - `FormTextField.name()` - Pre-configured for name input with proper capitalization
  - **DO NOT** use raw TextField or SecureField - always use FormTextField for consistency
  - Example usage:
  ```swift
  // Email field
  FormTextField.email(text: $email)
  
  // Password field with validation
  FormTextField.password(
      text: $password,
      validation: { $0.count >= 6 },
      errorMessage: "Password must be at least 6 characters"
  )
  
  // Custom field
  FormTextField(
      label: "Household Name",
      placeholder: "Enter household name",
      text: $householdName
  )
  ```