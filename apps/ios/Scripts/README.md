# Build and Utility Scripts

This directory contains scripts for building, testing, and maintaining the Jeeves iOS app.

## Available Scripts

### `build.sh`
**Purpose**: Build and test the iOS app using xcodebuild

**Usage**:
```bash
./Scripts/build.sh
```

**What it does**:
- Builds the JeevesKit framework for iOS Simulator
- Runs all unit tests
- Reports build and test results

### `generate-apollo-types.sh`
**Purpose**: Generate Swift types from GraphQL schema and operations

**Usage**:
```bash
./Scripts/generate-apollo-types.sh
```

**What it does**:
- Uses apollo-ios-cli to generate Swift types
- Reads GraphQL schema from `schema.graphqls`
- Processes operations from `Sources/JeevesKit/GraphQL/Operations/`
- Outputs generated code to `Sources/JeevesKit/GraphQL/Generated/`

**When to run**:
- After adding new GraphQL operations
- After updating the GraphQL schema
- When you get type mismatch errors

### `make-apollo-types-public.sh`
**Purpose**: Make generated Apollo types public for framework usage

**Usage**:
```bash
./Scripts/make-apollo-types-public.sh
```

**What it does**:
- Modifies generated GraphQL types to have public access level
- Ensures types can be used outside the JeevesKit framework
- Required for proper framework compilation

**When to run**:
- After generating new Apollo types
- If you get access level errors in generated code

### `run-swiftlint.sh`
**Purpose**: Run SwiftLint for code quality checks

**Usage**:
```bash
./Scripts/run-swiftlint.sh
```

**What it does**:
- Runs SwiftLint on all Swift source files
- Checks for code style violations
- Can auto-fix some issues with `--fix` flag

## Common Workflows

### After Adding New GraphQL Operations
```bash
# 1. Generate new types
./Scripts/generate-apollo-types.sh

# 2. Make types public (if needed)
./Scripts/make-apollo-types-public.sh

# 3. Build and test
./Scripts/build.sh
```

### Before Committing Code
```bash
# 1. Check code quality
./Scripts/run-swiftlint.sh

# 2. Build and test
./Scripts/build.sh
```

### After Updating GraphQL Schema
```bash
# 1. Fetch latest schema (if from backend)
./apollo-ios-cli fetch-schema

# 2. Generate new types
./Scripts/generate-apollo-types.sh

# 3. Make types public
./Scripts/make-apollo-types-public.sh

# 4. Build and test
./Scripts/build.sh
```

## Notes

- All scripts should be run from the iOS project root (`apps/ios/`)
- Scripts use `set -e` to fail fast on errors
- Build scripts target iOS Simulator by default
- Apollo code generation is configured in `apollo-codegen-config.json`