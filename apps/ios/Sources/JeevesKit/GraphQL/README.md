# Apollo GraphQL Integration

This directory contains the Apollo GraphQL client integration for the Jeeves iOS app with **SQLite cache persistence**, **reactive watchers**, and **offline support**.

## Directory Structure

```
GraphQL/
├── Operations/                    # GraphQL queries, mutations, and subscriptions
│   ├── CommonFragments.graphql   # Reusable GraphQL fragments
│   ├── HouseholdOperations.graphql
│   ├── HydrationOperations.graphql
│   ├── SubscriptionOperations.graphql
│   └── UserOperations.graphql
├── Generated/                     # Apollo-generated Swift types (DO NOT EDIT)
│   ├── Fragments/                # Generated fragment types
│   ├── Operations/               # Generated query/mutation/subscription classes
│   ├── Schema/                   # Generated schema types
│   │   ├── Objects/             # GraphQL object types
│   │   ├── InputObjects/        # Input type definitions
│   │   ├── CustomScalars/       # Custom scalar types (DateTime, etc.)
│   │   └── SchemaConfiguration.swift # Cache normalization config
│   └── JeevesGraphQL.graphql.swift
├── schema.graphqls               # GraphQL schema from backend
├── WatchManager.swift            # Reactive watcher management
├── WatchedResult.swift           # Observable reactive data container
└── README.md                     # This file
```

## Core Features

### 🚀 SQLite Cache Persistence (Default)

The Apollo client uses **SQLite persistent caching** by default, with in-memory fallback:

```swift
// From ApolloClientService.swift
private static func createPersistentCache() throws -> any NormalizedCache {
    let sqliteFileURL = URL(fileURLWithPath: documentsPath)
        .appendingPathComponent("jeeves_apollo_cache.sqlite")
    
    let sqliteCache = try SQLiteNormalizedCache(
        fileURL: sqliteFileURL,
        shouldVacuumOnClear: true
    )
    return sqliteCache
}

// Fallback to in-memory only if SQLite fails
do {
    cache = try createPersistentCache()
    logger.info("✅ Using SQLite cache for persistence")
} catch {
    logger.info("⚠️ Falling back to in-memory cache")
    cache = InMemoryNormalizedCache()
}
```

**Benefits**:
- Data persists across app launches
- Offline access to cached data
- Automatic cache normalization by entity ID
- Reactive UI updates when cache changes

### 🔄 Reactive Watchers

The app uses reactive watchers for automatic UI updates:

```swift
// Example from UserService.swift
public func watchCurrentUser() -> WatchedResult<User> {
    let result = WatchedResult<User>()
    
    let watcher = apolloClient.watch(
        query: GetCurrentUserQuery(),
        cachePolicy: .returnCacheDataAndFetch
    ) { graphQLResult in
        // Updates trigger automatic UI refresh
        if let userData = graphQLResult.data {
            result.update(value: mappedUser, source: source)
        }
    }
    
    currentUserApolloWatcher = watcher
    return result
}

// In ViewModels/Views
@Published var currentUser = userService.watchCurrentUser()
// UI automatically updates when cache changes!
```

### 🌐 WebSocket Subscriptions

Real-time updates via WebSocket subscriptions:

```swift
// WebSocket transport configuration
let webSocketTransport = WebSocketTransport(
    url: webSocketURL,
    config: WebSocketTransport.Configuration(
        connectingPayload: [
            "connection_init": ["Cookie": cookieHeader]
        ]
    )
)

// Subscription example
subscription OnUserUpdate($userId: ID!) {
    userUpdate(userId: $userId) {
        ...UserFields
    }
}
```

### 📱 Offline Support

Full offline support with graceful degradation:

```swift
// Cache-first policy for offline support
cachePolicy: .returnCacheDataAndFetch
// Returns cached data immediately, fetches in background

// Network error handling
if isNetworkConnectivityError(error) {
    logger.debug("📶 Network unavailable - offline mode")
    // App continues with cached data
}
```

## Authentication

### Cookie-Based Authentication (Better-Auth)

The app uses **cookie-based authentication** with Better-Auth:

```swift
// From ApolloClientService - Cookie injection
private final class CookieInjectionInterceptor: ApolloInterceptor {
    func interceptAsync<Operation>(...) {
        // Get Better-Auth session cookies
        let cookies = HTTPCookieStorage.shared.cookies(for: endpoint)
        
        if let authCookie = cookies?.first(where: { 
            $0.name.contains("better-auth") || 
            $0.name.contains("auth-token") 
        }) {
            let cookieHeader = "\(authCookie.name)=\(authCookie.value)"
            request.addHeader(name: "Cookie", value: cookieHeader)
        }
    }
}
```

**Note**: The app does NOT use Bearer token authentication.

## Cache Normalization

Apollo cache is normalized by entity ID for consistent updates:

```swift
// From SchemaConfiguration.swift
enum SchemaConfiguration: ApolloAPI.SchemaConfiguration {
    public static func cacheKeyInfo(for type: Object, object: ObjectData) -> CacheKeyInfo? {
        switch type {
        case JeevesGraphQL.Objects.User:
            if let id = object["id"] as? String {
                return CacheKeyInfo(id: id)  // Normalizes User:123
            }
        case JeevesGraphQL.Objects.Household:
            if let id = object["id"] as? String {
                return CacheKeyInfo(id: id)  // Normalizes Household:456
            }
        // ... other entities
        }
    }
}
```

**Result**: Mutations, queries, and subscriptions all update the same cache entry, triggering reactive watchers.

## Working with GraphQL

### 1. Define Operations

Create `.graphql` files in `Operations/`:

```graphql
# HouseholdOperations.graphql
query GetHousehold($input: GetHouseholdInput!) {
    household(input: $input) {
        ...HouseholdFields
    }
}

mutation CreateHousehold($input: CreateHouseholdInput!) {
    createHousehold(input: $input) {
        ...HouseholdFields
    }
}

# Use fragments for consistency
fragment HouseholdFields on Household {
    id
    name
    description
    created_by
    created_at
    updated_at
}
```

### 2. Generate Swift Types

Run the generation script:
```bash
./Scripts/generate-apollo-types.sh
```

This creates type-safe Swift code in the `Generated/` directory.

### 3. Use in Services with Reactive Watchers

```swift
// Watch pattern for reactive UI
public func watchHousehold(id: String) -> WatchedResult<Household> {
    let result = WatchedResult<Household>()
    
    let query = JeevesGraphQL.GetHouseholdQuery(
        input: GetHouseholdInput(id: id)
    )
    
    let watcher = apolloClient.watch(
        query: query,
        cachePolicy: .returnCacheDataAndFetch  // Offline-first
    ) { [weak result] graphQLResult in
        switch graphQLResult {
        case .success(let data):
            if let household = data.data?.household {
                let mapped = mapGraphQLHouseholdToDomain(household)
                let source: WatchedResult<Household>.DataSource = 
                    data.source == .cache ? .cache : .server
                result?.update(value: mapped, source: source)
            }
        case .failure(let error):
            if !isNetworkConnectivityError(error) {
                result?.updateError(error)
            }
            // Silently ignore network errors (offline mode)
        }
    }
    
    return result
}
```

## Apollo Configuration

### ApolloClientService

Located at `Sources/JeevesKit/Services/ApolloClientService.swift`

**Key Features**:
- **SQLite cache persistence** (primary)
- **In-memory cache** (fallback only)
- **Cookie-based authentication**
- **WebSocket support for subscriptions**
- **Split network transport** (HTTP + WebSocket)
- **Request/response logging**
- **Offline support**

### GraphQLService

Located at `Sources/JeevesKit/Services/GraphQLService.swift`

**Provides**:
- Type-safe query execution with cache policies
- Type-safe mutation execution
- Offline-first data fetching
- Network error resilience
- Cache management

## Error Handling

### Service Level

```swift
private func handleGraphQLError(_ error: Error, operation: String) -> Error {
    // Check for network connectivity first (offline mode)
    if isNetworkConnectivityError(error) {
        logger.debug("📶 Network unavailable for \(operation) - offline mode")
        return ServiceError.networkError(error)
    }
    
    if let graphQLError = error as? GraphQLError {
        return ServiceError.operationFailed(graphQLError.message ?? "GraphQL operation failed")
    }
    
    return ServiceError.operationFailed(error.localizedDescription)
}
```

### Common Error Types

- `ServiceError.notAuthenticated` - No valid session cookies
- `ServiceError.networkError` - Network connectivity issues (offline mode)
- `ServiceError.invalidData` - Unexpected response format
- `ServiceError.operationFailed` - Generic GraphQL errors

## Type Generation

### Configuration

The `apollo-codegen-config.json` file controls code generation:

```json
{
  "schemaNamespace": "JeevesGraphQL",
  "input": {
    "operationSearchPaths": ["Sources/**/*.graphql"],
    "schemaSearchPaths": ["Sources/JeevesKit/GraphQL/schema.graphqls"]
  },
  "output": {
    "testMocks": {
      "none": {}
    },
    "schemaTypes": {
      "path": "Sources/JeevesKit/GraphQL/Generated",
      "moduleType": {
        "embeddedInTarget": {
          "name": "JeevesKit",
          "accessModifier": "public"
        }
      }
    },
    "operations": {
      "inSchemaModule": {}
    }
  }
}
```

### Generated Types

All generated types are in the `JeevesGraphQL` namespace:

- **Queries**: `JeevesGraphQL.GetHouseholdQuery`
- **Mutations**: `JeevesGraphQL.CreateHouseholdMutation`
- **Subscriptions**: `JeevesGraphQL.OnUserUpdateSubscription`
- **Input Types**: `JeevesGraphQL.CreateHouseholdInput`
- **Schema Types**: `JeevesGraphQL.Household`
- **Fragments**: `JeevesGraphQL.HouseholdFields`

## Cache Management

### SQLite Persistent Cache

```swift
// Cache location
~/Library/Caches/jeeves_apollo_cache.sqlite

// Clear cache when needed (e.g., logout)
await apolloClientService.clearCache()
// Note: This removes ALL cached data from SQLite
```

### Cache Policies

```swift
// Offline-first (recommended)
.returnCacheDataAndFetch    // Returns cache immediately, fetches in background

// Cache-only
.returnCacheDataDontFetch   // Only uses cache, no network

// Network-only
.fetchIgnoringCacheData     // Always fetches (fails when offline)

// Cache-or-fetch
.returnCacheDataElseFetch   // Uses cache if available, else fetches
```

## Working with Nullable Fields

For optional GraphQL fields in mutations:

```swift
// Convert Swift optional to GraphQL nullable
description: description.map { GraphQLNullable<String>.some($0) } ?? .none
```

## Working with DateTime Scalar

The GraphQL schema uses a `DateTime` scalar type. All date conversions use centralized `DateUtilities`:

```swift
// The DateTime scalar is defined as a String in Swift
public typealias DateTime = String

// Always use DateUtilities for conversion
// From GraphQL DateTime to Swift Date:
let date = DateUtilities.dateFromGraphQL(graphqlUser.created_at)

// From Swift Date to GraphQL DateTime:
let dateTimeString = DateUtilities.graphQLStringFromDate(Date())

// In service mappings:
return User(
    id: graphqlUser.id,
    email: graphqlUser.email,
    createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlUser.created_at)
)
```

## Environment Configuration

Set endpoints in `.xcconfig` files:

```
# Development.xcconfig
GRAPHQL_ENDPOINT = http://localhost:3001/graphql

# Production.xcconfig
GRAPHQL_ENDPOINT = https://api.jeevesapp.com/graphql
```

## Best Practices

1. **Use reactive watchers** - Leverage `WatchedResult<T>` for automatic UI updates
2. **Cache-first approach** - Use `.returnCacheDataAndFetch` for offline support
3. **Define operations in `.graphql` files** - Don't construct queries in Swift
4. **Use fragments** - Ensure consistent field selection across operations
5. **Handle offline gracefully** - Check for network errors and continue with cache
6. **Map at service boundaries** - Convert GraphQL types to domain models
7. **Normalize cache entries** - Configure in SchemaConfiguration.swift

## Common Issues

### Types Not Found

**Problem**: `Cannot find 'JeevesGraphQL' in scope`

**Solution**: Run `./Scripts/generate-apollo-types.sh`

### Access Level Issues

**Problem**: Generated types have internal access

**Solution**: The generation script automatically fixes this with `make-apollo-types-public.sh`

### Schema Out of Sync

**Problem**: GraphQL errors about unknown fields

**Solution**: 
```bash
# Fetch latest schema
./apollo-ios-cli fetch-schema

# Regenerate types
./Scripts/generate-apollo-types.sh
```

### Watchers Not Updating

**Problem**: UI doesn't update when data changes

**Solution**: Check cache normalization in `SchemaConfiguration.swift` - entities must have ID-based cache keys

### Offline Mode Issues

**Problem**: App shows errors when offline

**Solution**: Use `.returnCacheDataAndFetch` cache policy and handle `ServiceError.networkError`

## Adding New Operations

1. Create/update `.graphql` file in `Operations/`
2. Run `./Scripts/generate-apollo-types.sh`
3. Implement reactive watcher in service
4. Map responses to domain models
5. Use `WatchedResult<T>` in ViewModels

## Example: Complete Feature Flow with Reactive Updates

```swift
// 1. Define in HouseholdOperations.graphql
mutation UpdateHousehold($input: UpdateHouseholdInput!) {
  updateHousehold(input: $input) {
    ...HouseholdFields
  }
}

// 2. Generate types
// Run: ./Scripts/generate-apollo-types.sh

// 3. Implement in HouseholdService with reactive watcher
public func updateHousehold(id: String, name: String) async throws -> Household {
    let mutation = JeevesGraphQL.UpdateHouseholdMutation(
        input: UpdateHouseholdInput(id: id, name: name)
    )
    
    let data = try await graphQLService.mutate(mutation)
    // Cache automatically updated, watchers notified!
    return mapGraphQLHouseholdToDomain(data.updateHousehold)
}

// 4. Watch in ViewModel
class HouseholdViewModel: ObservableObject {
    @Published var household: WatchedResult<Household>
    
    init(householdId: String) {
        self.household = householdService.watchHousehold(id: householdId)
        // UI automatically updates when mutation completes!
    }
}

// 5. Use in SwiftUI View
struct HouseholdView: View {
    @StateObject var viewModel: HouseholdViewModel
    
    var body: some View {
        Group {
            if let household = viewModel.household.value {
                Text(household.name)  // Auto-updates!
            }
        }
    }
}
```

## Related Documentation

- [Reactive Watching Pattern](../../../Documentation/REACTIVE_WATCHING_PATTERN.md)
- [Apollo Cache Persistence](../../../Documentation/APOLLO_CACHE_PERSISTENCE.md)
- [Offline Behavior](../../../Documentation/OFFLINE_BEHAVIOR.md)
- [Service Layer](../Services/README.md)