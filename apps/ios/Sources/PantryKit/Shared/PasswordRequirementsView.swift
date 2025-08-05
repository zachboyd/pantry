/*
 PasswordRequirementsView.swift
 PantryKit
 
 Visual component showing password requirements with real-time validation
 */

import SwiftUI

/// Shows password requirements with checkmarks for met requirements
public struct PasswordRequirementsView: View {
    let password: String
    let isExpanded: Bool
    
    // Validation requirements
    private var hasMinLength: Bool {
        password.count >= PasswordConstants.minimumLength
    }
    
    private var hasUppercase: Bool {
        password.contains(where: { $0.isUppercase })
    }
    
    private var hasLowercase: Bool {
        password.contains(where: { $0.isLowercase })
    }
    
    private var hasNumber: Bool {
        password.contains(where: { $0.isNumber })
    }
    
    // TODO: Add special character requirement when Phase 2 is implemented
    
    public init(password: String, isExpanded: Bool = true) {
        self.password = password
        self.isExpanded = isExpanded
    }
    
    public var body: some View {
        if isExpanded && !password.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                PasswordRequirementRow(
                    text: L("password.requirement.length", PasswordConstants.minimumLength),
                    isMet: hasMinLength
                )
                
                PasswordRequirementRow(
                    text: L("password.requirement.uppercase"),
                    isMet: hasUppercase
                )
                
                PasswordRequirementRow(
                    text: L("password.requirement.lowercase"),
                    isMet: hasLowercase
                )
                
                PasswordRequirementRow(
                    text: L("password.requirement.number"),
                    isMet: hasNumber
                )
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

/// Individual requirement row with checkmark
struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Text.tertiary)
                .font(.system(size: 12))
                .animation(.easeInOut(duration: 0.2), value: isMet)
            
            Text(text)
                .font(DesignTokens.Typography.Semantic.caption())
                .foregroundColor(isMet ? DesignTokens.Colors.Text.primary : DesignTokens.Colors.Text.secondary)
                .animation(.easeInOut(duration: 0.2), value: isMet)
        }
    }
}

// MARK: - Preview

#Preview("Password Requirements") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        VStack(alignment: .leading) {
            Text("Empty Password")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordRequirementsView(password: "")
        }
        
        VStack(alignment: .leading) {
            Text("Weak Password")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordRequirementsView(password: "pass")
        }
        
        VStack(alignment: .leading) {
            Text("Better Password")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordRequirementsView(password: "Password")
        }
        
        VStack(alignment: .leading) {
            Text("Strong Password")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordRequirementsView(password: "Password123")
        }
    }
    .padding()
}