/*
 HouseholdMembersView.swift
 JeevesKit

 View for displaying household members (view only for MVP)
 */

import SwiftUI

/// View for displaying household members
public struct HouseholdMembersView: View {
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: HouseholdMembersViewModel?
    @State private var membersWatch: WatchedResult<[HouseholdMember]>?

    let householdId: LowercaseUUID

    public init(householdId: LowercaseUUID) {
        self.householdId = householdId
    }

    public var body: some View {
        Group {
            if let membersWatch {
                if membersWatch.isLoading, membersWatch.value == nil {
                    // Initial loading state
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let members = membersWatch.value {
                    // Show members list
                    List {
                        ForEach(members) { member in
                            HouseholdMemberRowView(member: member, viewModel: viewModel)
                        }
                    }
                } else {
                    // Empty state
                    ContentUnavailableView(
                        L("household.members.empty.title"),
                        systemImage: "person.2.slash",
                        description: Text(L("household.members.empty.description")),
                    )
                }
            } else {
                // Loading initial state
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L("household.members"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Create ViewModel if needed
            if viewModel == nil {
                viewModel = try? factory?.makeHouseholdMembersViewModel(householdId: householdId)
            }

            // Set up watch for household members
            if let householdService = viewModel?.dependencies.householdService {
                membersWatch = householdService.watchHouseholdMembers(householdId: householdId)
            }

            // Load initial data
            await viewModel?.onAppear()
        }
        .onDisappear {
            Task {
                await viewModel?.onDisappear()
            }
        }
    }
}

/// Row view for displaying a household member
struct HouseholdMemberRowView: View {
    let member: HouseholdMember
    let viewModel: HouseholdMembersViewModel?

    @State private var userInfo: User?

    var body: some View {
        HStack {
            // Avatar using shared component
            AvatarView(
                user: userInfo,
                size: .medium,
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(DesignTokens.Typography.Semantic.cardTitle())
                    .foregroundColor(DesignTokens.Colors.Text.primary)

                // Only show email for non-AI users
                if let userInfo, !userInfo.isAi, let email = displayEmail {
                    Text(email)
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                } else if userInfo == nil, let email = displayEmail {
                    // Show email if we don't have user info (can't determine if AI)
                    Text(email)
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                }

                Text(L("household.member.joined_date", member.joinedDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Text.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .task {
            // Try to load user info if we have a viewModel
            if let userService = viewModel?.dependencies.userService {
                do {
                    userInfo = try await userService.getUser(id: member.userId)
                } catch {
                    // User info not available, will use fallback display
                }
            }
        }
    }

    // Computed properties for display
    private var displayName: String {
        userInfo?.name ?? member.name
    }

    private var displayEmail: String? {
        userInfo?.email ?? member.email
    }
}

// MARK: - Household Member Model (Placeholder)

// HouseholdMember model is defined in DependencyContainer.swift
// This extension adds display properties for the UI
public extension HouseholdMember {
    // For UI display, we'll use mock data since we don't have user lookup yet
    var name: String {
        // TODO: Look up user name from userId
        // For now, generate mock names based on userId
        "User \(userId.uuidString.prefix(3))"
    }

    var email: String {
        // TODO: Look up user email from userId
        // For now, generate mock emails
        "user\(userId.uuidString.prefix(3))@example.com"
    }

    /// Get member initials for avatar
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    /// Convenience property for UI compatibility
    var joinedDate: Date {
        joinedAt
    }
}

/// Extension for member role display properties
public extension MemberRole {
    var displayName: String {
        switch self {
        case .manager: "Manager"
        case .member: "Member"
        case .ai: "AI"
        }
    }

    var color: Color {
        switch self {
        case .manager: DesignTokens.Colors.Primary.base
        case .member: DesignTokens.Colors.Text.secondary
        case .ai: DesignTokens.Colors.Secondary.base
        }
    }
}

#Preview {
    NavigationStack {
        HouseholdMembersView(householdId: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }
}
