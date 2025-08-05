# Apollo GraphQL Integration

This directory contains the Apollo GraphQL client integration for the Pantry iOS app.

## Directory Structure

```
GraphQL/
├── Operations/           # GraphQL queries and mutations (.graphql files)
│   ├── AuthOperations.graphql
│   └── HouseholdOperations.graphql
├── Generated/            # Apollo-generated Swift types (DO NOT EDIT)
│   ├── Operations/       # Generated query/mutation classes
│   ├── Schema/          # Generated schema types
│   └── PantryGraphQL.graphql.swift
└── README.md            # This file
```

## Working with GraphQL

### 1. Define Operations

Create `.graphql` files in `Operations/`:

```graphql
# HouseholdOperations.graphql
query GetHousehold($input: GetHouseholdInputGql!) {
  household(input: $input) {
    id
    name
    description
    created_by
    created_at
    updated_at
  }
}

mutation CreateHousehold($input: CreateHouseholdInputGql!) {
  createHousehold(input: $input) {
    id
    name
    # ... other fields
  }
}
```

### 2. Generate Swift Types

Run the generation script:
```bash
./Scripts/generate-apollo-types.sh
```

This creates type-safe Swift code in the `Generated/` directory.

### 3. Use in Services

```swift
// Example from HouseholdService.swift
public func getCurrentHousehold() async throws -> Household? {
    let query = PantryGraphQL.GetAuthenticatedHouseholdQuery(
        input: PantryGraphQL.GetHouseholdInputGql(id: "current")
    )
    
    let data = try await graphQLService.query(query)
    return mapGraphQLHouseholdToDomain(data.household)
}
```

## Apollo Configuration

### ApolloClientService

Located at `Sources/PantryKit/Services/ApolloClientService.swift`

**Key Features**:
- Environment-based endpoint configuration
- Authentication interceptor for token management
- Request/response logging
- In-memory caching

### GraphQLService

Located at `Sources/PantryKit/Services/GraphQLService.swift`

**Provides**:
- Type-safe query execution
- Type-safe mutation execution
- Cache management
- Error handling

## Authentication

### Token Management

The `AuthTokenManager` stores tokens securely in Keychain:

```swift
// Token is automatically added to requests via AuthenticationInterceptor
public final class AuthenticationInterceptor: ApolloInterceptor {
    func interceptAsync<Operation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        // Add auth header if token exists
        if let token = await authTokenManager.getAuthToken() {
            request.addHeader(name: "Authorization", value: "Bearer \(token)")
        }
        // Continue chain...
    }
}
```

## Error Handling

### Service Level

```swift
private func handleGraphQLError(_ error: Error, operation: String) -> Error {
    if let graphQLError = error as? GraphQLError {
        return ServiceError.operationFailed(graphQLError.message ?? "GraphQL operation failed")
    }
    
    if let urlError = error as? URLError {
        return ServiceError.networkError(urlError)
    }
    
    return ServiceError.operationFailed(error.localizedDescription)
}
```

### Common Error Types

- `ServiceError.notAuthenticated` - No valid auth token
- `ServiceError.networkError` - Network connectivity issues
- `ServiceError.invalidData` - Unexpected response format
- `ServiceError.operationFailed` - Generic GraphQL errors

## Type Generation

### Configuration

The `apollo-codegen-config.json` file controls code generation:

```json
{
  "schemaNamespace": "PantryGraphQL",
  "input": {
    "operationSearchPaths": ["Sources/**/*.graphql"],
    "schemaSearchPaths": ["schema.gql"]
  },
  "output": {
    "schemaTypes": {
      "path": "Sources/PantryKit/GraphQL/Generated",
      "moduleType": {
        "embeddedInTarget": {
          "name": "PantryKit",
          "accessModifier": "public"
        }
      }
    }
  }
}
```

### Generated Types

All generated types are in the `PantryGraphQL` namespace:

- **Queries**: `PantryGraphQL.GetHouseholdQuery`
- **Mutations**: `PantryGraphQL.CreateHouseholdMutation`
- **Input Types**: `PantryGraphQL.CreateHouseholdInputGql`
- **Schema Types**: `PantryGraphQL.Household`

## Caching

The Apollo client uses in-memory caching by default:

```swift
// Clear cache when needed (e.g., logout)
await apolloClientService.clearCache()
```

## Working with Nullable Fields

For optional GraphQL fields in mutations:

```swift
// Convert Swift optional to GraphQL nullable
description: description.map { GraphQLNullable<String>.some($0) } ?? .none
```

## Working with DateTime Scalar

The GraphQL schema uses a `DateTime` scalar type for dates. All date conversions should use the centralized `DateUtilities`:

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

**Note**: The `DateUtilities` class handles dates with and without fractional seconds, and provides thread-safe date formatting.

## Environment Configuration

Set endpoints in `.xcconfig` files:

```
# Development.xcconfig
GRAPHQL_ENDPOINT = http://localhost:3001/graphql

# Production.xcconfig
GRAPHQL_ENDPOINT = https://api.pantryapp.com/graphql
```

## Best Practices

1. **Define operations in `.graphql` files** - Don't construct queries in Swift
2. **Always regenerate after schema changes** - Keep types in sync
3. **Map at service boundaries** - Convert GraphQL types to domain models
4. **Handle all errors** - Network, GraphQL, and business logic errors
5. **Use fragments for reusable fields** - Reduce duplication

## Common Issues

### Types Not Found

**Problem**: `Cannot find 'PantryGraphQL' in scope`

**Solution**: Run `./Scripts/generate-apollo-types.sh`

### Access Level Issues

**Problem**: Generated types have internal access

**Solution**: The generation script automatically fixes this with `make-apollo-types-public.sh`

### Schema Out of Sync

**Problem**: GraphQL errors about unknown fields

**Solution**: Update `schema.gql` from backend and regenerate

## Adding New Operations

1. Create/update `.graphql` file in `Operations/`
2. Run `./Scripts/generate-apollo-types.sh`
3. Use the generated types in your service
4. Map responses to domain models

## Example: Complete Feature Flow

```swift
// 1. Define in HouseholdOperations.graphql
mutation UpdateHousehold($id: String!, $name: String!) {
  updateHousehold(id: $id, name: $name) {
    id
    name
    updated_at
  }
}

// 2. Generate types
// Run: ./Scripts/generate-apollo-types.sh

// 3. Use in HouseholdService
public func updateHousehold(id: String, name: String) async throws -> Household {
    let mutation = PantryGraphQL.UpdateHouseholdMutation(
        id: id, 
        name: name
    )
    
    let data = try await graphQLService.mutate(mutation)
    return mapGraphQLHouseholdToDomain(data.updateHousehold)
}

// 4. Map to domain model
private func mapGraphQLHouseholdToDomain(
    _ graphqlHousehold: PantryGraphQL.UpdateHouseholdMutation.Data.UpdateHousehold
) -> Household {
    return Household(
        id: graphqlHousehold.id,
        name: graphqlHousehold.name,
        // ... map other fields
    )
}
```