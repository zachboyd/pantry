/*
 PasswordConstants.swift
 JeevesKit
 
 Shared constants for password validation across the app
 */

import Foundation

/// Shared constants for password validation and UI consistency
@MainActor
public enum PasswordConstants {
    /// Minimum required password length
    public static let minimumLength = 8
    
    /// Placeholder text for password fields with dynamic length
    public static var placeholder: String {
        L("auth.password.placeholder.with_length", minimumLength)
    }
    
    /// Placeholder text for password confirmation fields
    public static var confirmPlaceholder: String {
        L("auth.confirm_password.placeholder")
    }
    
    /// Error message for passwords that are too short
    public static var tooShortError: String {
        L("auth.validation.password_short.with_length", minimumLength)
    }
    
    /// Error message for passwords that don't match
    public static var mismatchError: String {
        L("auth.validation.passwords_not_match")
    }
}