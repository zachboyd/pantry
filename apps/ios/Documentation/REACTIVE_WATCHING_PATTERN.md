# Reactive Watching Pattern Documentation

This document outlines the common pattern used for setting up reactive watchers in AppState that automatically update when Apollo cache changes occur.

## Pattern Overview

The reactive watching pattern consists of three layers:

1. **Service Layer**: Create `WatchedResult<T>` using Apollo watchers
2. **AppState Layer**: Use `withObservationTracking` to monitor the WatchedResult
3. **UI Layer**: SwiftUI automatically reacts to AppState changes

## Service Layer Implementation

Services should provide watch methods that return `WatchedResult<T>`:

```swift
// In Service (e.g., HouseholdService, UserService)
public func watchHousehold(id: String) -> WatchedResult<Household> {
    // Create WatchedResult
    let result = WatchedResult<Household>()
    result.setLoading(true)
    
    // Create Apollo watcher
    let watcher = apolloClient.watch(query: query, cachePolicy: .returnCacheDataAndFetch) { graphQLResult in
        // Transform GraphQL result to domain model
        // Update WatchedResult
        result.update(value: domainModel, source: .cache/.server)
    }
    
    return result
}
```

## AppState Integration Pattern

AppState should set up watchers using this pattern:

```swift
// In AppState
private func setupEntityWatcher<T: Equatable>(
    _ entity: T?,
    entityName: String,
    watcherCreator: (String) -> WatchedResult<T>,
    entityUpdater: @escaping (T) -> Void
) {
    guard let entity = entity else {
        logger.debug("🔍 No current \(entityName) to watch yet")
        return
    }
    
    logger.info("👁️ Setting up reactive \(entityName) watcher")
    
    let watchedResult = watcherCreator(entity.id)
    
    Task { @MainActor in
        var lastKnownValue = entity
        
        while !Task.isCancelled {
            withObservationTracking {
                _ = watchedResult.value
                _ = watchedResult.error
                _ = watchedResult.isLoading
            } onChange: {
                if let newValue = watchedResult.value,
                   newValue.id == lastKnownValue.id,
                   newValue != lastKnownValue {
                    logger.info("🔄 \(entityName) watcher: detected change")
                    entityUpdater(newValue)
                    lastKnownValue = newValue
                }
                
                if let error = watchedResult.error {
                    logger.warning("⚠️ \(entityName) watcher error: \(error)")
                }
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
    }
    
    logger.info("✅ \(entityName) watcher setup complete")
}

// Usage examples:
private func setupHouseholdWatcher() {
    setupEntityWatcher(
        currentHousehold,
        entityName: "Household",
        watcherCreator: { id in householdService.watchHousehold(id: id) },
        entityUpdater: { [weak self] household in self?.currentHousehold = household }
    )
}

private func setupUserWatcher() {
    setupEntityWatcher(
        currentUser,
        entityName: "User", 
        watcherCreator: { _ in userService.watchCurrentUser() },
        entityUpdater: { [weak self] user in self?.currentUser = user }
    )
}
```

## Key Benefits of This Pattern

1. **Consistency**: Same pattern for all entities (User, Household, etc.)
2. **Maintainability**: Changes to the pattern only need to be made in one place
3. **Reusability**: Easy to add new reactive entities
4. **Error Handling**: Centralized error logging and handling
5. **Performance**: Avoids unnecessary updates through proper change detection

## Current Implementation

The current working implementation in AppState follows this pattern manually for household watching. The pattern can be extracted into a reusable utility once Swift 6 concurrency patterns are fully stabilized.

## Future Improvements

1. Extract into `ReactiveWatcherManager<T>` when Swift 6 concurrency stabilizes
2. Add generic change detection strategies
3. Support for multiple watchers per entity type
4. Automatic cleanup and memory management