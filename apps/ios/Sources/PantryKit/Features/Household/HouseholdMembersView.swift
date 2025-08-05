/*
 HouseholdMembersView.swift
 PantryKit

 View for displaying household members (view only for MVP)
 */

import SwiftUI

/// View for displaying household members
public struct HouseholdMembersView: View {
    let householdId: String
    @State private var members: [HouseholdMember] = [
        // Mock data for development
        HouseholdMember(id: "1", userId: "user1", householdId: "household1", role: .owner, joinedAt: Date()),
        HouseholdMember(id: "2", userId: "user2", householdId: "household1", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 7)),
        HouseholdMember(id: "3", userId: "user3", householdId: "household1", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 14)),
        HouseholdMember(id: "4", userId: "user4", householdId: "household1", role: .member, joinedAt: Date().addingTimeInterval(-86400 * 30)),
    ]

    public init(householdId: String) {
        self.householdId = householdId
    }

    public var body: some View {
        List {
            ForEach(members) { member in
                HouseholdMemberRowView(member: member)
            }
        }
        .navigationTitle(L("household.members"))
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Row view for displaying a household member
struct HouseholdMemberRowView: View {
    let member: HouseholdMember

    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(member.role == .owner ? DesignTokens.Colors.Primary.base : DesignTokens.Colors.Secondary.base)
                .frame(width: DesignTokens.ComponentSize.Avatar.medium, height: DesignTokens.ComponentSize.Avatar.medium)
                .overlay {
                    Text(member.initials)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name)
                        .font(DesignTokens.Typography.Semantic.cardTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)

                    if member.role == .owner {
                        Text(L("household.role.owner"))
                            .font(DesignTokens.Typography.Semantic.caption())
                            .foregroundColor(DesignTokens.Colors.Primary.base)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.Primary.light)
                            .cornerRadius(4)
                    }
                }

                Text(member.email)
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Text.secondary)

                Text(L("household.member.joined_date", member.joinedDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Text.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
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
        return "User \(userId.prefix(3))"
    }

    var email: String {
        // TODO: Look up user email from userId
        // For now, generate mock emails
        return "user\(userId.prefix(3))@example.com"
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
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }

    var color: Color {
        switch self {
        case .owner: return DesignTokens.Colors.Primary.base
        case .admin: return DesignTokens.Colors.Secondary.base
        case .member: return DesignTokens.Colors.Text.secondary
        }
    }
}

#Preview {
    NavigationStack {
        HouseholdMembersView(householdId: "1")
    }
}
