# AppSections - Centralized App Section Icons and Labels

## Overview

`AppSections` provides a centralized system for managing app section icons, labels, and configurations across the Jeeves app. This ensures consistency in how sections are presented throughout the app, whether in the tab bar, empty states, or other UI components.

## Key Features

- **Centralized Section Configuration**: All section-related icons, labels, and settings in one place
- **Single Icon Definition**: Each section has ONE icon definition used everywhere (tab bar, empty states, etc.)
- **Consistent Empty States**: Pre-configured empty state messages for each section
- **Type-Safe Section Identifiers**: Enum-based section identification prevents typos and ensures consistency
- **Accessibility Support**: Built-in accessibility identifiers for UI testing

## Usage Examples

### Getting Section Information

```swift
// Get the localized label for a section
let pantryLabel = AppSections.label(for: .pantry)  // "Pantry"

// Get the SF Symbol icon name (used everywhere)
let pantryIcon = AppSections.icon(for: .pantry)  // "archivebox"

// Empty state icon returns the same icon for consistency
let pantryEmptyIcon = AppSections.emptyStateIcon(for: .pantry)  // "archivebox"
```

### Using in Views

```swift
// Create a Label view for a section
AppSections.makeLabel(for: .lists)

// Create just the icon with custom color
AppSections.makeIcon(for: .settings, color: .blue)

// Create an empty state for a section
EmptyStateView(
    config: AppSections.emptyStateConfig(
        for: .pantry,
        action: { /* custom action */ }
    )
)
```

### Tab Bar Integration

The `MainTabView` uses AppSections to ensure consistency:

```swift
// Tab bar items use AppSections for labels and icons
.tabItem {
    Label(tab.title, systemImage: tab.iconName)
}

// Where title and iconName are provided by AppSections
var title: String {
    AppSections.label(for: AppSections.Section(from: self)!)
}

var iconName: String {
    AppSections.icon(for: AppSections.Section(from: self)!)
}
```

### Empty State Integration

Tab views use AppSections for consistent empty states:

```swift
// JeevesTabView empty state
EmptyStateView(config: AppSections.emptyStateConfig(
    for: .pantry,
    action: {
        Task { @MainActor in
            viewModel.showAddItemSheet()
        }
    }
))
```

## Section Configuration

### Available Sections

| Section | Icon | Label Key | Accessibility ID |
|-----|------|-----------|------------------|
| Pantry | `archivebox` | `tabs.pantry` | `pantryTab` |
| Chat | `message` | `tabs.chat` | `chatTab` |
| Lists | `list.bullet.clipboard` | `tabs.lists` | `listsTab` |
| Settings | `gearshape` | `tabs.settings` | `settingsTab` |
| Profile | `person.circle` | `settings.profile` | `profileTab` |

### Icon Selection Philosophy

- **Single Icon Per Section**: Each section uses the same icon everywhere for complete consistency
- **Meaningful Icons**: Icons are chosen to best represent the feature's purpose
- **SF Symbol Compatibility**: All icons are valid SF Symbols that render properly

## Advanced Usage

See `AppSections+Examples.swift` for more complex usage examples including:
- Custom tab bars
- Section navigation items
- Section info cards
- Accessibility implementations

## Best Practices

1. **Always use AppSections** for section-related UI to ensure consistency
2. **Use the appropriate icon** - section icon for navigation, empty state icon for content
3. **Leverage the pre-configured empty states** rather than creating custom ones
4. **Maintain the enum** when adding new sections to ensure all utilities work correctly
5. **Test accessibility** using the provided accessibility identifiers

## Household Utilities

AppSections also provides utilities for household-related UI elements:

### Household Icons

```swift
// Access predefined household icons
AppSections.HouseholdIcons.household     // "house.circle"
AppSections.HouseholdIcons.members       // "person.2.circle"
AppSections.HouseholdIcons.settings      // "gearshape.circle"
AppSections.HouseholdIcons.create        // "plus.circle"
AppSections.HouseholdIcons.join          // "arrow.right.circle"
AppSections.HouseholdIcons.switcher      // "arrow.left.arrow.right.circle"
AppSections.HouseholdIcons.invite        // "square.and.arrow.up"
AppSections.HouseholdIcons.noHousehold   // "house.circle"
```

### Household Empty States

```swift
// Create a household-related empty state
EmptyStateView(
    config: AppSections.householdEmptyStateConfig(
        icon: AppSections.HouseholdIcons.noHousehold,
        titleKey: "household.no_household_selected",
        subtitleKey: "household.no_household_selected_message",
        actions: [/* actions */]
    )
)
```

## Adding New Sections

To add a new section:

1. Add the section to the `AppSections.Section` enum
2. Update the `label(for:)` function with the localization key
3. Update the `icon(for:)` function with the SF Symbol name
4. Update the `hasSymbolVariant(for:)` function if needed
5. Update the `accessibilityIdentifier(for:)` function
6. Update the `emptyStateIcon(for:)` function
7. Update the `emptyStateConfig(for:)` function with appropriate messages
8. Add corresponding localization strings
9. Update the conversion functions if using `MainTab` enum