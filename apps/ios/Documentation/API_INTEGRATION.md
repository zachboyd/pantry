# API Integration Guide

This guide shows how to work with GraphQL in the Jeeves iOS app using Apollo Client.

## Quick Links

- **[GraphQL Documentation](../Sources/JeevesKit/GraphQL/README.md)** - Apollo client details
- **[Service Layer Guide](../Sources/JeevesKit/Services/README.md)** - Service patterns
- **[Development Guide](DEVELOPMENT_GUIDE.md)** - Step-by-step examples
- **GraphQL Operations**: `Sources/JeevesKit/GraphQL/Operations/`
- **Generated Types**: `Sources/JeevesKit/GraphQL/Generated/`

## Architecture Overview

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│   ViewModel     │────▶│   Service    │────▶│  GraphQL    │
└─────────────────┘     └──────────────┘     └─────────────┘
                                                     │
                                                     ▼
                                              ┌─────────────┐
                                              │   Apollo    │
                                              └─────────────┘
```

## Key Components

### 1. Apollo Client Service
- **Location**: `Sources/JeevesKit/Services/ApolloClientService.swift`
- **Purpose**: Manages Apollo client lifecycle and configuration
- **Features**: 
  - Environment-based endpoint configuration
  - Authentication interceptor integration
  - Cache management

### 2. GraphQL Service
- **Location**: `Sources/JeevesKit/Services/GraphQLService.swift`
- **Purpose**: High-level GraphQL operations abstraction
- **Features**:
  - Type-safe query and mutation methods
  - Error handling with custom error types
  - Cache management utilities

### 3. Authentication
- **Token Management**: `AuthTokenManager` handles secure token storage
- **Interceptor**: `AuthenticationInterceptor` adds Bearer tokens automatically
- **Headers**: User ID and authentication headers added to all requests

### 4. Code Generation
- **Script**: `./Scripts/generate-apollo-types.sh`
- **Config**: `apollo-codegen-config.json`
- **Output**: `Sources/JeevesKit/GraphQL/Generated/`

## Working with GraphQL

### 1. Adding a New Query

Create in `Sources/JeevesKit/GraphQL/Operations/YourOperations.graphql`:

```graphql
query GetItems($householdId: String!) {
  items(householdId: $householdId) {
    id
    name
    quantity
    expirationDate
  }
}
```

### 2. Generate Swift Types

```bash
./Scripts/generate-apollo-types.sh
```

### 3. Use in Service

```swift
@MainActor
public final class ItemService {
    private let graphQLService: GraphQLServiceProtocol
    
    public func getItems(householdId: String) async throws -> [Item] {
        let query = JeevesGraphQL.GetItemsQuery(householdId: householdId)
        let data = try await graphQLService.query(query)
        return data.items.map { mapToDomainModel($0) }
    }
}
```

## Real Examples from Codebase

### Query Example - Get Household

```swift
// From HouseholdService.swift
public func getCurrentHousehold() async throws -> Household? {
    guard authService.isAuthenticated else {
        throw ServiceError.notAuthenticated
    }
    
    let query = JeevesGraphQL.GetAuthenticatedHouseholdQuery(
        input: JeevesGraphQL.GetHouseholdInputGql(id: "current")
    )
    
    let data = try await graphQLService.query(query)
    return mapGraphQLHouseholdToDomain(data.household)
}
```

### Mutation Example - Create Household

```swift
// From HouseholdService.swift
public func createHousehold(name: String, description: String?) async throws -> Household {
    let mutation = JeevesGraphQL.CreateHouseholdMutation(
        input: JeevesGraphQL.CreateHouseholdInputGql(
            name: name,
            description: description.map { GraphQLNullable<String>.some($0) } ?? .none
        )
    )
    
    let data = try await graphQLService.mutate(mutation)
    return mapGraphQLHouseholdToDomain(data.createHousehold)
}
```

## Environment Configuration

### Setting Up Endpoints

In `Config/Development.xcconfig`:
```
GRAPHQL_ENDPOINT = http://localhost:3001/graphql
```

### Available Environments

| Environment | Typical Endpoint | Config File |
|------------|------------------|-------------|
| Local Development | `http://localhost:3001/graphql` | `Development.xcconfig` |
| Staging | `https://staging-api.jeevesapp.com/graphql` | `Staging.xcconfig` |
| Production | `https://api.jeevesapp.com/graphql` | `Production.xcconfig` |

## Error Handling

### Service Layer Errors

```swift
public enum ServiceError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidData(String)
    case operationFailed(String)
}
```

### Handling in ViewModels

```swift
await performTask(loadingKey: "loadData") {
    do {
        let data = try await householdService.getCurrentHousehold()
        updateState { $0.household = data }
    } catch {
        // Error automatically handled by BaseViewModel
        throw ViewModelError.custom("Failed to load household")
    }
}
```

## Authentication

### How It Works

1. **Token Storage**: AuthTokenManager stores tokens in Keychain
2. **Automatic Headers**: Apollo interceptor adds auth headers to all requests
3. **Session Management**: Better-Auth cookie-based sessions (pending completion)

### Auth Flow

```swift
// Sign in
let result = try await authService.signIn(email: email, password: password)

// Token is automatically stored and used for subsequent requests
```

## Common Patterns

### Handling Optional Fields

```swift
// For GraphQL nullable fields:
description: description.map { GraphQLNullable<String>.some($0) } ?? .none
```

### Date Handling

All date conversions between GraphQL DateTime strings and Swift Date objects use the centralized `DateUtilities`:

```swift
// Converting from GraphQL to Date
let date = DateUtilities.dateFromGraphQL(graphqlDateTime)
let dateOrNow = DateUtilities.dateFromGraphQLOrNow(graphqlDateTime)

// Converting from Date to GraphQL
let graphqlString = DateUtilities.graphQLStringFromDate(date)

// Example in service mapping
private func mapUserFromGraphQL(_ user: JeevesGraphQL.User) -> User {
    return User(
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: DateUtilities.dateFromGraphQLOrNow(user.created_at)
    )
}
```

**Important**: Never create new `ISO8601DateFormatter` instances. Always use `DateUtilities` for thread-safe, consistent date handling.

### Mapping to Domain Models

```swift
private func mapGraphQLHouseholdToDomain(
    _ graphqlHousehold: JeevesGraphQL.GetAuthenticatedHouseholdQuery.Data.Household
) -> Household {
    return Household(
        id: graphqlHousehold.id,
        name: graphqlHousehold.name,
        ownerId: graphqlHousehold.created_by,
        members: [],
        inviteCode: nil,
        createdAt: DateUtilities.dateFromGraphQLOrNow(graphqlHousehold.created_at.description)
    )
}
```

## Best Practices

1. **Always use Services** - Don't call GraphQL directly from ViewModels
2. **Map at boundaries** - Convert GraphQL types to domain models in services
3. **Handle all errors** - Use proper error types and recovery
4. **Cache wisely** - Services implement smart caching (see HouseholdService)
5. **Type safety** - Let Apollo generate types, don't create manually

## Troubleshooting

- **Types not found?** Run `./Scripts/generate-apollo-types.sh`
- **Auth failing?** Check token in AuthTokenManager
- **Network errors?** Verify endpoint in .xcconfig file

For more issues, see [Troubleshooting Guide](TROUBLESHOOTING.md).