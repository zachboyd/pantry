# Offline Behavior

## Overview

The Jeeves iOS app gracefully handles offline scenarios without showing error screens or alerts to users. When the network is unavailable, the app continues to function using cached data from Apollo's SQLite persistence layer and silently retries network operations in the background.

## Apollo Cache Architecture

### Two-Tier Cache System (NEW)
The app now uses a sophisticated **two-tier caching system** that combines in-memory and SQLite caches:

#### Primary Layer: In-Memory Cache
- Ultra-fast read/write operations (< 1ms)
- Immediate data availability
- Automatically cleared on iOS memory warnings
- No disk I/O overhead

#### Secondary Layer: SQLite Persistence
- Persistent storage across app launches (`~/Library/Caches/jeeves_apollo_cache.sqlite`)
- Survives app termination and updates
- Automatic backup for memory cache
- Enables true offline functionality

#### How It Works
1. **Read Path**: Memory → SQLite → Network
   - First checks in-memory cache (microseconds)
   - Falls back to SQLite if not in memory (milliseconds)
   - Promotes SQLite data to memory for future access
   - Only fetches from network if not cached anywhere

2. **Write Path**: Parallel updates to both caches
   - Writes to memory for immediate availability
   - Writes to SQLite for persistence
   - Both caches stay synchronized

### Cache Normalization
- All GraphQL responses are normalized by entity ID (configured in `SchemaConfiguration.swift`)
- Cache updates are reactive - UI automatically updates when cache changes
- Mutations and subscriptions update the same cache entries that queries watch

### Cache Policies for Offline Support
- **`.returnCacheDataAndFetch`** (Recommended): Returns cached data immediately, fetches fresh data in background
- **`.returnCacheDataElseFetch`** (Default): Returns cache if available, only fetches if cache is empty
- **`.fetchIgnoringCacheData`**: Always fetches from network (will fail when offline)

## Key Behaviors

### 1. Silent Network Error Handling
- **No Error Screens**: Network connectivity errors do NOT transition the app to the error phase
- **No Alerts**: Users are not shown alerts for network connectivity issues
- **Quiet Logging**: Network errors are logged at DEBUG level instead of ERROR level
- **Cache-First**: When using `.returnCacheDataAndFetch`, cached data is returned immediately even when offline

### 2. Network Error Detection
The app identifies network connectivity errors by checking for:
- URLError codes: `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotConnectToHost`, `.timedOut`, `.cannotFindHost`, `.dnsLookupFailed`
- NSURLErrorDomain error codes (Objective-C compatibility)
- Common error messages containing: "could not connect to the server", "network", "connection", "offline"

### 3. Service-Level Handling

#### AppState
- Catches `ServiceError.networkError` during hydration
- Remains in current phase instead of transitioning to error phase
- Allows app to continue with cached data

#### GraphQLService (Fixed for Offline Support)
- **Previous Issue**: Would wait for network response even with `.returnCacheDataAndFetch`, causing errors when offline
- **Current Behavior**: Returns cached data immediately when available, network errors don't override cache
- Logs network errors at DEBUG level with 📶 emoji
- Returns `ServiceError.networkError` for proper upstream handling
- Avoids flooding logs with ERROR level messages

#### ApolloClientService
- Request interceptor detects network errors
- Logs at DEBUG level for offline scenarios
- Provides user-friendly error messages

#### PermissionService
- Continues with cached permission context
- Silently handles subscription failures due to network

## Implementation Details

### Network Error Detection Helper
All services use a consistent helper method to detect network connectivity errors:

```swift
private func isNetworkConnectivityError(_ error: Error) -> Bool {
    // Check URLError codes
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .timedOut,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            break
        }
    }
    
    // Check NSURLErrorDomain
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        // Similar checks for NSURLError codes
    }
    
    // Check error description
    let errorDescription = error.localizedDescription.lowercased()
    return errorDescription.contains("could not connect to the server") ||
           errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("offline")
}
```

## User Experience

### What Works Offline
✅ **Viewing cached data:**
- User profile information
- Household lists and details
- Previously loaded members
- Cached items and lists
- App navigation and UI

### What Requires Network
❌ **Mutations and new data:**
- Creating households
- Joining households
- Updating user information
- Creating/editing items
- Initial sign in
- First-time data loads

### What Users See
- App continues to function with cached data
- No error dialogs or fullscreen errors
- Seamless experience when network returns
- Reactive watchers update UI when network returns

### What Users Don't See
- Network error messages
- Connection failure alerts
- Error screens blocking app usage
- Network retry attempts

## Future Enhancements

Potential improvements for offline support:
1. **Offline Indicator**: Subtle UI indicator showing offline status
2. **Background Sync**: Queue operations for when network returns
3. **Offline Mode**: Full offline capability with local storage
4. **Smart Retry**: Exponential backoff for network retries
5. **Connection Monitoring**: Proactive network status detection

## Testing Offline Behavior

To test offline behavior:
1. Launch the app normally
2. Disable network connection (airplane mode or turn off WiFi)
3. Verify app continues without error screens
4. Re-enable network and verify seamless recovery

## Log Messages

### Normal Operation (Online)
```
✅ [GraphQL] Success: Query completed
📡 Network request completed
```

### Offline Operation
```
📶 Network unavailable for GetCurrentUserQuery - offline mode
📶 Network unavailable for permission updates - offline mode
```

Note: All offline messages are logged at DEBUG level to reduce log noise.