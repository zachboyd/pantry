/*
 AppSections+Examples.swift
 JeevesKit

 Examples of using AppSections across the app
 */

import SwiftUI

// MARK: - Example Usage

/// Example: Using AppSections in a custom button
struct SectionButton: View {
    let section: AppSections.Section
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                AppSections.makeIcon(for: section, color: isSelected ? DesignTokens.Colors.Primary.base : .secondary)
                    .font(.system(size: 24))
                
                Text(AppSections.label(for: section))
                    .font(.caption)
                    .foregroundColor(isSelected ? DesignTokens.Colors.Primary.base : .secondary)
            }
        }
    }
}

/// Example: Using AppSections in a navigation item
struct SectionNavigationItem: View {
    let section: AppSections.Section
    
    var body: some View {
        NavigationLink(destination: destinationView(for: section)) {
            HStack {
                AppSections.makeLabel(for: section)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for section: AppSections.Section) -> some View {
        // Return appropriate view based on section
        EmptyView()
    }
}

/// Example: Using AppSections in a widget or other UI element
struct SectionInfoCard: View {
    let section: AppSections.Section
    
    var body: some View {
        VStack(spacing: 12) {
            AppSections.makeIcon(for: section)
                .font(.largeTitle)
            
            Text(AppSections.label(for: section))
                .font(.headline)
            
            // Could include additional info like item counts, etc.
        }
        .padding()
        .background(DesignTokens.Colors.Surface.secondary)
        .cornerRadius(12)
    }
}

/// Example: Using AppSections for empty states anywhere in the app
struct GenericEmptyView: View {
    let section: AppSections.Section
    let customAction: (@Sendable () -> Void)?
    
    var body: some View {
        EmptyStateView(
            config: AppSections.emptyStateConfig(
                for: section,
                action: customAction
            )
        )
    }
}

/// Example: Using AppSections in a custom tab bar
struct CustomTabBar: View {
    @Binding var selectedSection: AppSections.Section
    let sections: [AppSections.Section]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(sections, id: \.self) { section in
                SectionButton(
                    section: section,
                    isSelected: selectedSection == section,
                    action: { selectedSection = section }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Colors.Surface.primary)
    }
}

/// Example: Using AppSections for accessibility
struct AccessibleSectionView: View {
    let section: AppSections.Section
    
    var body: some View {
        AppSections.makeLabel(for: section)
            .accessibilityIdentifier(AppSections.accessibilityIdentifier(for: section))
            .accessibilityLabel(AppSections.label(for: section))
            .accessibilityHint("Double tap to open \(AppSections.label(for: section))")
    }
}

// MARK: - Preview Examples

#Preview("Section Button Examples") {
    VStack(spacing: 20) {
        // Individual section buttons
        HStack(spacing: 20) {
            SectionButton(section: .pantry, isSelected: true, action: {})
            SectionButton(section: .chat, isSelected: false, action: {})
            SectionButton(section: .lists, isSelected: false, action: {})
        }
        
        Divider()
        
        // Section info cards
        HStack(spacing: 20) {
            SectionInfoCard(section: .pantry)
            SectionInfoCard(section: .lists)
        }
        
        Divider()
        
        // Navigation items
        VStack(alignment: .leading) {
            SectionNavigationItem(section: .pantry)
            SectionNavigationItem(section: .chat)
            SectionNavigationItem(section: .lists)
        }
        .padding(.horizontal)
    }
    .padding()
}

#Preview("Empty State Examples") {
    VStack(spacing: 40) {
        // Jeeves empty state
        GenericEmptyView(section: .pantry, customAction: {
            print("Add pantry item")
        })
        .frame(height: 200)
        
        Divider()
        
        // Lists empty state
        GenericEmptyView(section: .lists, customAction: {
            print("Create list")
        })
        .frame(height: 200)
    }
    .padding()
}

#Preview("Custom Tab Bar") {
    @Previewable @State var selectedSection: AppSections.Section = .pantry
    
    VStack {
        Spacer()
        
        // Content area
        AppSections.makeLabel(for: selectedSection)
            .font(.largeTitle)
        
        Spacer()
        
        // Custom tab bar
        CustomTabBar(
            selectedSection: $selectedSection,
            sections: [.pantry, .chat, .lists, .settings]
        )
    }
}