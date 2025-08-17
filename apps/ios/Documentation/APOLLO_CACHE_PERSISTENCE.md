# Apollo GraphQL Cache Persistence

## Overview

The iOS app now uses **SQLite persistence** for the Apollo GraphQL cache, which means:
- GraphQL query results are persisted across app launches
- Offline access to previously fetched data
- Faster app startup with cached data available immediately
- Reduced network requests for unchanged data

## Implementation Details

### Cache Type
We're using `SQLiteNormalizedCache` from the `ApolloSQLite` package, which provides:
- On-disk persistence using SQLite database
- Normalized cache structure for efficient updates
- Automatic cache key management

### Cache Location
The SQLite database is stored at:
```
~/Library/Caches/jeeves_apollo_cache.sqlite
```

### Configuration
- **Location**: App's cache directory (can be cleared by iOS if needed)
- **Vacuum on Clear**: Enabled to ensure PII is fully removed when cache is cleared
- **Fallback**: If SQLite initialization fails, the app falls back to in-memory cache
- **Cache Normalization**: Entities are normalized by ID in `SchemaConfiguration.swift` to ensure mutations, subscriptions, and queries all update the same cache entry

### Trade-offs

#### SQLite Cache (Current Implementation)
**Pros:**
- Data persists across app launches
- Offline access to cached data
- Reduces network usage
- Improves perceived performance on app launch

**Cons:**
- Slightly slower than in-memory cache due to disk I/O
- Takes up disk space
- Cache can become stale if not properly managed

#### In-Memory Cache (Fallback)
**Pros:**
- Fastest possible cache performance
- No disk space usage
- Always starts fresh

**Cons:**
- No persistence - all data lost on app close
- Requires network fetch on every app launch
- No offline capability

## Cache Management

### Clearing the Cache
The cache can be cleared programmatically:
```swift
await apolloClientService.clearCache()
```

This should be done when:
- User signs out
- User switches accounts
- Data corruption is suspected
- As part of troubleshooting

### Cache Policies
The app uses Apollo's cache policies to control data freshness:
- `.returnCacheDataAndFetch`: Returns cached data immediately, then fetches fresh data
- `.fetchIgnoringCacheData`: Always fetches fresh data from network
- `.returnCacheDataDontFetch`: Only uses cached data, no network request

## Future Enhancements

### Possible Improvements
1. **Hybrid Caching**: Create a custom `NormalizedCache` implementation that uses both in-memory and SQLite:
   - In-memory for hot data (frequently accessed)
   - SQLite for cold data (infrequently accessed)
   - Would require implementing the `NormalizedCache` protocol

2. **Cache Expiration**: Implement TTL (time-to-live) for cached entries to ensure data freshness

3. **Cache Size Management**: Monitor and limit cache size to prevent excessive disk usage

4. **Encrypted Cache**: Use SQLCipher for encrypted SQLite database if storing sensitive data

## Testing Cache Persistence

To verify cache persistence is working:

1. Launch the app and load some data (households, user info)
2. Force quit the app
3. Turn on Airplane Mode
4. Relaunch the app
5. Previously loaded data should still be visible (from cache)

## Performance Considerations

- SQLite cache adds ~5-10ms overhead compared to in-memory cache
- This overhead is negligible compared to network request times (100-500ms)
- The performance trade-off is worth it for the persistence benefits
- Cache reads are still much faster than network fetches

## Monitoring

Watch for these logs in the console:
- "📁 SQLite cache location: ..." - Shows where cache is stored
- "✅ Created SQLite cache for persistence" - Successful SQLite setup
- "⚠️ Falling back to in-memory cache only" - SQLite failed, using fallback