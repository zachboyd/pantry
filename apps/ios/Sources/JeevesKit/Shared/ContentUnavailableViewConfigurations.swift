import SwiftUI

/// Reusable configurations for ContentUnavailableView throughout the app
public enum ContentUnavailableViewConfiguration {
    // MARK: - Common Empty States

    /// Configuration for when no items exist in a list
    @MainActor
    public static func noItems(
        type: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        ContentUnavailableView {
            Label(L("empty.no_items", type), systemImage: systemImage)
        } description: {
            Text(L("empty.items_will_appear", type.lowercased()))
        } actions: {
            if let actionTitle = actionTitle, let action = action {
                SecondaryButton(actionTitle, action: action)
            }
        }
    }

    /// Configuration for search with no results
    @MainActor
    public static func noSearchResults(
        searchText: String
    ) -> some View {
        ContentUnavailableView {
            Label(L("search.no_results"), systemImage: "magnifyingglass")
        } description: {
            Text(L("search.no_results_for", searchText))
        }
    }

    /// Configuration for network errors
    @MainActor
    public static func networkError(
        retry: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(L("error.connection"), systemImage: "wifi.exclamationmark")
        } description: {
            Text(L("error.connection_message"))
        } actions: {
            SecondaryButton(L("error.try_again"), action: retry)
        }
    }

    /// Configuration for general errors
    @MainActor
    public static func error(
        message: String,
        retry: (() -> Void)? = nil
    ) -> some View {
        ContentUnavailableView {
            Label(L("error.generic_title"), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry = retry {
                SecondaryButton(L("error.try_again"), action: retry)
            }
        }
    }

    // MARK: - Feature-Specific Empty States

    /// Configuration for empty pantry
    @MainActor
    public static func emptyPantry(
        addAction: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(L("pantry.empty"), systemImage: AppSections.emptyStateIcon(for: .pantry))
        } description: {
            Text(L("pantry.empty_message"))
        } actions: {
            PrimaryButton(L("pantry.add_first_item"), action: addAction)
                .frame(maxWidth: 300)
        }
    }

    /// Configuration for no shopping lists
    @MainActor
    public static func noShoppingLists(
        createAction: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(L("lists.empty"), systemImage: "list.bullet.clipboard")
        } description: {
            Text(L("lists.empty_message"))
        } actions: {
            PrimaryButton(L("lists.create"), action: createAction)
                .frame(maxWidth: 300)
        }
    }

    /// Configuration for no recipes
    @MainActor
    public static func noRecipes(
        browseAction: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(L("recipes.empty"), systemImage: "book.closed")
        } description: {
            Text(L("recipes.empty_message"))
        } actions: {
            PrimaryButton(L("recipes.browse"), action: browseAction)
                .frame(maxWidth: 300)
        }
    }

    /// Configuration for no household members
    @MainActor
    public static func noHouseholdMembers(
        inviteAction: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(L("household.no_other_members"), systemImage: "person.2")
        } description: {
            Text(L("household.invite_members_message"))
        } actions: {
            PrimaryButton(L("household.invite_members"), action: inviteAction)
                .frame(maxWidth: 300)
        }
    }

    /// Configuration for no notifications
    @MainActor
    public static var noNotifications: some View {
        ContentUnavailableView {
            Label(L("notifications.empty"), systemImage: "bell")
        } description: {
            Text(L("notifications.all_caught_up"))
        }
    }

    /// Configuration for feature coming soon
    @MainActor
    public static func comingSoon(
        feature: String
    ) -> some View {
        ContentUnavailableView {
            Label(L("coming.soon"), systemImage: "clock.arrow.circlepath")
        } description: {
            Text(L("coming.soon_message", feature))
        }
    }
}

// MARK: - View Extension for Convenience

public extension View {
    /// Apply a ContentUnavailableView configuration conditionally
    @ViewBuilder
    func contentUnavailable<Content: View>(
        when condition: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if condition {
            content()
        } else {
            self
        }
    }
}
