# CASLSwift

A Swift implementation of CASL (an isomorphic authorization library) for iOS applications.

## Overview

CASLSwift provides the same API as CASL's JavaScript implementation, enabling consistent permission management across platforms. It's designed specifically for iOS 18+ and leverages Swift 6's concurrency features.

This is a pure Swift implementation that is backend-agnostic. It handles permission evaluation and rule management, while the consuming application is responsible for fetching and persisting permissions.

## Features

- Type-safe permission checking
- O(1) performance for basic permission checks
- Swift 6 concurrency support with actor isolation
- SwiftUI integration with `@Observable` pattern
- Thread-safe with `Sendable` conformance
- MVVM architecture friendly

## Installation

CASLSwift is included as part of the Jeeves iOS app and can be imported via:

```swift
import CASLSwift
```

## Basic Usage

```swift
// Define abilities
let builder = AbilityBuilder<Ability>()
builder.can("read", "Post")
builder.can("manage", "Post") { post in
    post.authorId == currentUser.id
}
let ability = builder.build()

// Check permissions
if ability.can("read", post) {
    // User can read this post
}
```

## JSON Serialization

CASLSwift supports importing and exporting permissions using **CASL's exact JSON format**:

```swift
// Import permissions from JSON (CASL RawRule format)
let permissionsJSON = """
[
  {
    "action": "read",
    "subject": "Article"
  },
  {
    "action": ["create", "update"],
    "subject": "Article",
    "conditions": {
      "authorId": "${userId}"
    }
  },
  {
    "action": "moderate"
  }
]
"""

let ability = try PureAbility.from(json: permissionsJSON.data(using: .utf8)!)

// Export current rules to JSON
let exportedJSON = try ability.toJSON()
```

### Format Compatibility

The JSON format **exactly matches** CASL's JavaScript RawRule interface:
- Actions and subjects can be strings or arrays
- Subject is optional (for claim-based rules)
- Fields can be a single string or array
- Priority is NOT included in JSON (internal only)
- Full compatibility with CASL backend APIs

## Architecture

- **Core**: Core ability and rule engine
- **Conditions**: Condition evaluation system
- **Rules**: Rule definition and storage
- **Builders**: AbilityBuilder implementation
- **Extensions**: Swift-specific enhancements