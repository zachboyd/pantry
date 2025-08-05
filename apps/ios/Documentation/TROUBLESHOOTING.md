# iOS Logging Debug Guide

## Current Setup
Your app uses Apple's `os.log` framework with the `Logger` API. The logging is properly implemented with:
- Subsystem: `com.pantry.app`
- Various categories for different services
- Different log levels (debug, info, warning, error)

## Why You Might Not See Logs

### 1. **Log Level Visibility**
- `logger.debug()` messages are NOT visible by default in Xcode console
- Only `info`, `notice`, `warning`, `error`, `critical`, and `fault` levels show up
- Many of your logs use `.debug()` level

### 2. **Where to Look for Logs**

#### In Xcode (Recommended for Development):
1. Run your app from Xcode
2. Make sure Debug Area is visible: **View → Debug Area → Show Debug Area**
3. Look for messages with emojis like 🚀, ✅, ❌, etc.
4. You should now see test messages from `LoggingTest.testAllLogLevels()`

#### In Console.app:
1. Open **Console.app** on your Mac
2. Select your iPhone simulator or device
3. Click "Start" to begin streaming
4. In the search field, type: `subsystem:com.pantry.app`
5. You'll see ALL log levels including debug

#### In Terminal (for Simulator):
```bash
# Stream logs from simulator
xcrun simctl spawn booted log stream --subsystem com.pantry.app --level debug
```

### 3. **Quick Fixes**

#### Option 1: Change Debug Logs to Info (Recommended)
Change critical debug logs to info level so they show in Xcode:

```swift
// Instead of:
logger.debug("🚀 Starting important operation")

// Use:
logger.info("🚀 Starting important operation")
```

#### Option 2: Add Print Statements for Development
During development, you can add print statements alongside logger calls:

```swift
#if DEBUG
print("🚀 [DEBUG] Starting operation")
#endif
logger.debug("🚀 Starting operation")
```

#### Option 3: Install Logging Profile (Advanced)
Install a debug logging profile on your device/simulator to see all log levels.

## Testing Your Logging

I've added `LoggingTest.swift` that will run when your app starts. You should see:
- ❌ ERROR, 🚨 CRITICAL, and 💥 FAULT messages in Xcode console
- 🖨️ PRINT message always visible
- Other messages visible in Console.app

## Recommended Changes

1. **For Development**: Change important `.debug()` calls to `.info()`
2. **For Production**: Keep using appropriate log levels
3. **For Debugging**: Use Console.app with subsystem filtering

## Environment-Specific Logging

You can create a wrapper to handle logging differently in DEBUG vs RELEASE:

```swift
extension Logger {
    func devLog(_ message: String) {
        #if DEBUG
        // In debug, use info level so it shows in Xcode
        self.info("\(message)")
        #else
        // In release, use debug level
        self.debug("\(message)")
        #endif
    }
}
```