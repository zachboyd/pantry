import SwiftUI

/// A shared header toolbar that displays the household name and profile avatar
public struct SharedHeaderToolbar: View {
    @Environment(\.appState) private var appState
    @State private var showingProfile = false
    
    private let title: String
    
    public init(title: String) {
        self.title = title
    }
    
    public var body: some View {
        HStack {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                if let household = appState?.currentHousehold {
                    Text(household.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Profile Avatar
            AvatarView(
                user: appState?.currentUser,
                size: .small,
                onTap: {
                    showingProfile = true
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showingProfile) {
            let currentAppState = appState
            if #available(iOS 16.4, *) {
                UserProfileView(
                    currentUser: currentAppState?.currentUser,
                    currentHousehold: currentAppState?.currentHousehold,
                    households: [], // Will be loaded by ViewModel
                    onSignOut: {
                        Logger.app.info("🚪 UserProfileView onSignOut called from SharedHeaderToolbar")
                        if let appState = currentAppState {
                            await appState.signOut()
                            showingProfile = false
                        } else {
                            Logger.app.error("❌ AppState is nil in SharedHeaderToolbar onSignOut")
                        }
                    },
                    onSelectHousehold: { household in
                        Logger.app.info("🏠 UserProfileView selectHousehold called from SharedHeaderToolbar")
                        currentAppState?.selectHousehold(household)
                        showingProfile = false
                    }
                )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            } else {
                UserProfileView(
                    currentUser: currentAppState?.currentUser,
                    currentHousehold: currentAppState?.currentHousehold,
                    households: [], // Will be loaded by ViewModel
                    onSignOut: {
                        Logger.app.info("🚪 UserProfileView onSignOut called from SharedHeaderToolbar")
                        if let appState = currentAppState {
                            await appState.signOut()
                            showingProfile = false
                        } else {
                            Logger.app.error("❌ AppState is nil in SharedHeaderToolbar onSignOut")
                        }
                    },
                    onSelectHousehold: { household in
                        Logger.app.info("🏠 UserProfileView selectHousehold called from SharedHeaderToolbar")
                        currentAppState?.selectHousehold(household)
                        showingProfile = false
                    }
                )
            }
        }
    }
}

/// A view modifier to add the shared header toolbar to any view
public struct SharedHeaderToolbarModifier: ViewModifier {
    let title: String
    
    public func body(content: Content) -> some View {
        VStack(spacing: 0) {
            SharedHeaderToolbar(title: title)
            
            Divider()
            
            content
        }
        .navigationBarHidden(true)
    }
}

public extension View {
    /// Adds a shared header toolbar to the view
    func sharedHeaderToolbar(title: String) -> some View {
        modifier(SharedHeaderToolbarModifier(title: title))
    }
}

// MARK: - Previews

#Preview("Shared Header Toolbar") {
    NavigationStack {
        VStack {
            Text("Content goes here")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        }
        .sharedHeaderToolbar(title: "Jeeves")
    }
    .withAppState()
}