# Jeeves iOS App

Smart home management iOS application built with SwiftUI and Swift Package Manager.

## Requirements

- **Xcode 26** (Beta) - [Download from Apple Developer](https://developer.apple.com/xcode/)
  - Sign in with your Apple Account at [developer.apple.com](https://developer.apple.com) to access beta downloads
  - The latest version is Xcode 26 beta 5
  - Includes SDKs for iOS 26, iPadOS 26, tvOS 26, watchOS 26, macOS Tahoe 26, and visionOS 26
- iOS 18.0+
- Swift 6.0
- **SwiftFormat** (for code formatting)
  ```bash
  brew install swiftformat
  ```

## VS Code / Cursor Setup

For the best development experience, install these extensions:

1. **Sweetpad** - Run iOS simulator directly from VS Code/Cursor
   - Extension ID: `sweetpad.sweetpad`
   - Allows running and debugging iOS apps without leaving the editor
2. **Swift Language Support**
   - Extension ID: `sswg.swift-lang`
   - Provides syntax highlighting, code completion, and diagnostics
3. **SwiftFormat**
   - Extension ID: `vknabel.vscode-swiftformat`
   - Automatic code formatting for Swift files

### Quick Setup

```bash
# Install extensions via command palette (Cmd+P)
ext install sweetpad.sweetpad
ext install sswg.swift-lang
ext install vknabel.vscode-swiftformat
```

After installing Sweetpad, you can:

- Press `Cmd+Shift+R` to run the app in simulator
- Use the Sweetpad panel in the sidebar to select devices
- View build logs directly in VS Code

## Project Structure

```
apps/ios/
├── Package.swift                    # Swift Package Manager configuration
├── Jeeves.xcworkspace/             # Xcode workspace
├── Jeeves.xcodeproj/               # Xcode project
├── Jeeves/                         # iOS app target
│   └── Jeeves/                    # App source files
│       ├── JeevesApp.swift        # Main app entry point
│       └── Assets.xcassets/       # App assets
├── Sources/                        # JeevesKit framework source
│   └── JeevesKit/                 # Main framework module
├── Tests/                          # Unit tests
├── Config/                         # Environment configurations
├── Scripts/                        # Build and utility scripts
├── Documentation/                  # Project documentation
├── apollo-ios-cli                  # Apollo code generation CLI
├── apollo-codegen-config.json      # Apollo configuration
└── schema.gql                      # GraphQL schema
```

## Configuration

1. Copy `Config/Example.xcconfig` to create environment-specific configurations:
   - `Development.xcconfig`
   - `Staging.xcconfig`
   - `Production.xcconfig`

2. Fill in your GraphQL endpoint and authentication settings in each configuration file.

## Development

### Building

```bash
# Build and test
./Scripts/build.sh

# Or manually with Swift Package Manager
swift build
swift test
```

### Opening in Xcode

Open `Jeeves.xcworkspace` in Xcode to work with the project.

## Architecture

This project uses:

- **SwiftUI** for the user interface
- **Swift Package Manager** for dependency management
- **Apollo GraphQL** for API communication (direct service-to-GraphQL pattern)
- **Better-Auth** for authentication
- **MVVM + Observable** architecture pattern
- **No Repository Pattern** - Services interact directly with GraphQL for cleaner architecture

## Documentation

### Essential Guides

- **[Development Guide](Documentation/DEVELOPMENT_GUIDE.md)** - Step-by-step guide for common tasks 🆕
- **[Architecture Guide](Documentation/ARCHITECTURE.md)** - How to work with the app architecture
- **[API Integration](Documentation/API_INTEGRATION.md)** - GraphQL operations and service patterns
- **[Deployment](Documentation/DEPLOYMENT.md)** - Build, test, and release procedures
- **[Troubleshooting](Documentation/TROUBLESHOOTING.md)** - Debug logging and common issues

### Component Documentation

- **[GraphQL Integration](Sources/JeevesKit/GraphQL/README.md)** - Apollo setup and usage
- **[Service Layer](Sources/JeevesKit/Services/README.md)** - How to use and extend services
- **[ViewModels](Sources/JeevesKit/ViewModels/README.md)** - ViewModel patterns and examples

## Key Technologies

- **SwiftUI** - Modern declarative UI framework
- **Apollo GraphQL** - Type-safe API client (v1.23.0+)
- **Swift 6** - With strict concurrency checking
- **@Observable** - Native reactive state management
- **Keychain** - Secure authentication token storage

## Testing

```bash
# Run all tests
swift test

# Test in Xcode
⌘+U
```

Key test files:

- `Tests/JeevesKitTests/` - Unit tests
- `Tests/JeevesKitTests/Mocks/` - Mock implementations

## Debugging Tips

1. **Logs not showing?** See [Troubleshooting Guide](Documentation/TROUBLESHOOTING.md)
2. **GraphQL errors?** Check Apollo configuration in `ApolloClientService.swift`
3. **Build failures?** Try `swift package reset` then rebuild
4. **Type errors?** Regenerate GraphQL types: `./Scripts/generate-apollo-types.sh`
