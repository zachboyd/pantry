/*
 PasswordStrengthMeter.swift
 JeevesKit
 
 Visual password strength indicator with color-coded bar
 */

import SwiftUI

/// Password strength levels
public enum PasswordStrength: CaseIterable {
    case veryWeak
    case weak
    case fair
    case good
    case strong
    
    var color: Color {
        switch self {
        case .veryWeak: return DesignTokens.Colors.Status.error
        case .weak: return .orange
        case .fair: return .yellow
        case .good: return DesignTokens.Colors.Status.success
        case .strong: return DesignTokens.Colors.Status.success
        }
    }
    
    @MainActor
    var label: String {
        switch self {
        case .veryWeak: return L("password.strength.very_weak")
        case .weak: return L("password.strength.weak")
        case .fair: return L("password.strength.fair")
        case .good: return L("password.strength.good")
        case .strong: return L("password.strength.strong")
        }
    }
    
    var progress: CGFloat {
        switch self {
        case .veryWeak: return 0.2
        case .weak: return 0.4
        case .fair: return 0.6
        case .good: return 0.8
        case .strong: return 1.0
        }
    }
}

/// Visual password strength meter with progress bar
public struct PasswordStrengthMeter: View {
    let password: String
    
    private var strength: PasswordStrength {
        calculateStrength(for: password)
    }
    
    public init(password: String) {
        self.password = password
    }
    
    public var body: some View {
        if !password.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(L("password.strength.label"))
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                    
                    Text(strength.label)
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(strength.color)
                        .animation(.easeInOut(duration: 0.2), value: strength)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignTokens.Colors.Surface.tertiary)
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(strength.color)
                            .frame(width: geometry.size.width * strength.progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: strength)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    /// Calculate password strength based on various criteria
    private func calculateStrength(for password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .veryWeak }
        
        var score = 0
        
        // Length scoring
        if password.count >= PasswordConstants.minimumLength {
            score += 1
        }
        if password.count >= 12 {
            score += 1
        }
        if password.count >= 16 {
            score += 1
        }
        
        // Character variety scoring
        if password.contains(where: { $0.isUppercase }) {
            score += 1
        }
        if password.contains(where: { $0.isLowercase }) {
            score += 1
        }
        if password.contains(where: { $0.isNumber }) {
            score += 1
        }
        // Special characters (TODO: Add when Phase 2 is implemented)
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) {
            score += 1
        }
        
        // Map score to strength
        switch score {
        case 0...1: return .veryWeak
        case 2...3: return .weak
        case 4...5: return .fair
        case 6: return .good
        case 7...: return .strong
        default: return .veryWeak
        }
    }
}

// MARK: - Preview

#Preview("Password Strength Meter") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        VStack(alignment: .leading) {
            Text("Very Weak")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordStrengthMeter(password: "pass")
        }
        
        VStack(alignment: .leading) {
            Text("Weak")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordStrengthMeter(password: "password")
        }
        
        VStack(alignment: .leading) {
            Text("Fair")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordStrengthMeter(password: "Password1")
        }
        
        VStack(alignment: .leading) {
            Text("Good")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordStrengthMeter(password: "Password123")
        }
        
        VStack(alignment: .leading) {
            Text("Strong")
                .font(DesignTokens.Typography.Semantic.body())
            PasswordStrengthMeter(password: "MyP@ssw0rd123!")
        }
    }
    .padding()
}