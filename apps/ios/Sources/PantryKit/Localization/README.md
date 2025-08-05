# Pantry iOS Localization System

This document explains the localization system implemented for the Pantry iOS app, following the same pattern as the Travel app.

## Overview

The localization system provides:
- **Simple function-based API** using `L("key")` for strings
- **Runtime language switching** via LocalizationManager
- **Automatic English fallback** for missing translations
- **Pluralization support** using `Lp("key", count)`
- **String extensions** for convenience (`.localized`)
- **Multiple language support** with easy expansion

## Architecture

### Core Components

1. **`LocalizedString.swift`** - Helper functions
   - `L("key")` - Get localized string
   - `Lp("key", count)` - Get localized plural string
   - String extensions for convenience

2. **`LocalizationManager.swift`** - Runtime management
   - Singleton that manages current language
   - Handles language switching
   - Provides English fallback for missing translations
   - Observable for SwiftUI integration

3. **`Localizable.strings`** - Translation files
   - Organized by feature with `// MARK:` comments
   - Currently supports English (en.lproj)
   - Ready for additional languages

## Usage Examples

### Basic String Access

```swift
// Simple text
Text(L("app.name"))

// Navigation title
.navigationTitle(L("tabs.pantry"))

// Button with localized title
Button(L("save")) {
    // action
}

// TextField with placeholder
TextField(L("auth.email.placeholder"), text: $email)
```

### Formatted Strings

```swift
// String with arguments
let message = L("welcome.message", userName)

// Plural strings
let itemCount = Lp("items.count", 5) // "5 items"

// Using string extension
let title = "profile.title".localized
```

### SwiftUI Integration

```swift
// Alert with localized strings
.alert(L("error"), isPresented: $showError) {
    Button(L("ok")) { }
} message: {
    Text(errorMessage)
}

// Conditional text
Text(isSignUp ? L("auth.button.create") : L("auth.button.signin"))
```

### Language Switching

```swift
// Change app language
LocalizationManager.shared.setLanguage("es")

// Get current language
let currentLang = LocalizationManager.shared.currentLanguage
```

## Adding New Strings

1. **Add to `Localizable.strings`**:
```
// MARK: - New Feature
"new_feature.title" = "New Feature Title";
"new_feature.description" = "Feature description";
```

2. **Use in your view**:
```swift
Text(L("new_feature.title"))
Text(L("new_feature.description"))
```

3. **For plurals, add to `.stringsdict` file** (when needed):
```xml
<key>items.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@items@</string>
    <key>items</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>one</key>
        <string>%d item</string>
        <key>other</key>
        <string>%d items</string>
    </dict>
</dict>
```

## Localization Guidelines

### String Key Naming Convention

- Use dot notation: `feature.component.property`
- Keep keys lowercase with dots as separators
- Examples:
  - `auth.button.signin` - Sign in button
  - `auth.error.invalid_credentials` - Invalid credentials error
  - `pantry.add_item` - Add item button in pantry
  - `profile.edit.title` - Edit profile title

### Organization

- Group related strings with `// MARK:` comments
- Order alphabetically within sections
- Keep related functionality together
- Follow the Travel app's established patterns

### Best Practices

- Use descriptive keys that indicate context
- Avoid abbreviations in keys
- Include UI element type in key when relevant (button, title, placeholder)
- Keep English translations concise and clear

## Testing Localization

### Preview in Different Languages

```swift
#Preview("Spanish") {
    YourView()
        .onAppear {
            LocalizationManager.shared.setLanguage("es")
        }
}

#Preview("French") {
    YourView()
        .onAppear {
            LocalizationManager.shared.setLanguage("fr")
        }
}
```

### Runtime Language Switching

```swift
// In your settings view
Picker("Language", selection: $selectedLanguage) {
    Text("English").tag("en")
    Text("Spanish").tag("es")
    Text("French").tag("fr")
}
.onChange(of: selectedLanguage) { newValue in
    LocalizationManager.shared.setLanguage(newValue)
}
```

### Testing Missing Translations

The LocalizationManager automatically falls back to English if a translation is missing, and then to the key itself if not found in English either.

## Adding New Languages

1. Create a new `.lproj` folder (e.g., `es.lproj` for Spanish)
2. Copy `en.lproj/Localizable.strings` to the new folder
3. Translate all strings in the new file
4. Add `.stringsdict` file for pluralization rules if needed
5. Test using LocalizationManager:
   ```swift
   LocalizationManager.shared.setLanguage("es")
   ```

## Best Practices

1. **Never hardcode strings** in views - always use `L("key")`
2. **Follow Travel app patterns** for consistency across projects
3. **Use descriptive keys** that explain the string's purpose and context
4. **Test all languages** when adding new strings
5. **Handle empty states** with appropriate messages
6. **Keep translations concise** for better UI fit
7. **Update all language files** when adding new keys

## Common Patterns

### Empty States
```swift
EmptyStateView(
    config: EmptyStateConfig(
        icon: "basket",
        title: L("pantry.no_items"),
        subtitle: L("pantry.add_first_item"),
        actionTitle: L("pantry.add_item")
    ) {
        // action
    }
)
```

### Form Validation
```swift
if !email.contains("@") {
    errorMessage = L("auth.validation.invalid_email")
}
```

### Loading States
```swift
Text(isLoading ? L("loading") : L("done"))

// Or for specific operations
Text(L(isSaving ? "loading.save" : "save"))
```

### Error Handling
```swift
// Generic error
errorMessage = L("error.generic_message")

// Specific errors
errorMessage = L("auth.error.invalid_credentials")
```

## Migration Checklist

When migrating a view to use localization:

1. ✅ Replace all hardcoded strings with `L("key")`
2. ✅ Add new keys to `Localizable.strings`
3. ✅ Update navigation titles
4. ✅ Update button labels
5. ✅ Update text fields and placeholders  
6. ✅ Update alert messages
7. ✅ Update accessibility labels
8. ✅ Test with different languages using LocalizationManager

## Supported Languages

Currently supported:
- English (en) - Base language

Planned additions (following Travel app):
- Spanish (es)
- French (fr) 
- German (de)
- Italian (it)
- Portuguese (pt)
- Japanese (ja)
- Korean (ko)
- Chinese Simplified (zh)
- Arabic (ar) - with RTL support

## Localization Workflow

1. Developers add keys to `en.lproj/Localizable.strings`
2. Keys are extracted and sent for translation
3. Translated files are added to respective `.lproj` folders
4. App automatically uses correct language based on device settings
5. Users can override in app settings