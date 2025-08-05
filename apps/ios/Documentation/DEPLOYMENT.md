# Pantry iOS Deployment Guide

Quick reference for building and deploying the Pantry iOS app.

## Prerequisites

- Xcode 16.0+
- Apple Developer Account
- Code signing certificates installed

## Environment Configuration

Each `.xcconfig` file in `Config/` should define:

```
GRAPHQL_ENDPOINT = http://localhost:3001/graphql  // or your environment URL
APP_BUNDLE_IDENTIFIER = com.pantryapp.ios
APP_NAME = Pantry Dev
APP_VERSION = 1.0.0
BUILD_NUMBER = 1
```

## Build & Run

### Command Line
```bash
# Quick build
./Scripts/build.sh

# Generate Apollo types
./Scripts/generate-apollo-types.sh
```

### Xcode
1. Open `Pantry.xcworkspace`
2. Select scheme (Development/Staging/Production)
3. Press ⌘+R to run

## TestFlight Release

1. Select "Any iOS Device" in Xcode
2. Product → Archive
3. In Organizer: Distribute App → App Store Connect
4. Wait for processing (~15 minutes)
5. Add to TestFlight test groups in App Store Connect

## Bundle Identifiers

| Environment | Bundle ID | Purpose |
|------------|-----------|---------|
| Development | `com.pantryapp.ios` | Local development |
| Staging | `com.pantryapp.ios.staging` | QA testing |
| Production | `com.pantryapp.ios` | App Store release |

## Troubleshooting

### Code Signing Issues
- Check provisioning profiles in Apple Developer Portal
- Ensure "Automatically manage signing" is enabled in Xcode

### Archive Not Appearing
- Clean build folder: ⇧⌘K
- Reset package cache: `swift package reset`

### Apollo Type Generation
```bash
# If types are missing or outdated
./apollo-ios-cli generate
./Scripts/make-apollo-types-public.sh
```

---

*Last Updated: January 2025*