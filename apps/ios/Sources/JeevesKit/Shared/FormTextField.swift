/*
 FormTextField.swift
 JeevesKit

 Form-specific text field component with validation, error handling, and consistent styling
 */

import SwiftUI

/// Form-specific text field component with built-in validation and error handling
public struct FormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let autocorrectionDisabled: Bool
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let validation: ((String) -> Bool)?
    let errorMessage: String?

    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool

    public init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrectionDisabled: Bool = false,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        validation: ((String) -> Bool)? = nil,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.validation = validation
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Label
            Text(label)
                .font(DesignTokens.Typography.Semantic.caption())
                .foregroundColor(hasError ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Text.secondary)

            // Input field with container
            HStack(spacing: DesignTokens.Spacing.sm) {
                inputField

                // Show/hide password toggle for secure fields
                if isSecure {
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.BorderRadius.sm)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .cornerRadius(DesignTokens.BorderRadius.sm)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            // Error message - always present to avoid layout shifts
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Status.error)
                    .padding(.leading, DesignTokens.Spacing.xs)
                    .opacity(hasError ? 1.0 : 0.0)
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .textContentType(textContentType)
                    .autocorrectionDisabled(autocorrectionDisabled)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
            }
        }
        .modifier(AccessibilityModifier(
            identifier: accessibilityIdentifier,
            label: accessibilityLabel,
            hint: accessibilityHint
        ))
    }

    private var hasError: Bool {
        if let validation = validation, !text.isEmpty {
            return !validation(text)
        }
        return false
    }

    private var backgroundColor: Color {
        DesignTokens.Colors.Surface.secondary
    }

    private var borderColor: Color {
        if hasError {
            return DesignTokens.Colors.Status.error
        } else if isFocused {
            return .accentColor
        } else {
            return Color.clear
        }
    }
}

// MARK: - Convenience Initializers

public extension FormTextField {
    /// Creates an email input field with appropriate settings
    static func email(
        label: String = "Email",
        placeholder: String = "Enter your email",
        text: Binding<String>,
        accessibilityIdentifier: String? = nil
    ) -> FormTextField {
        FormTextField(
            label: label,
            placeholder: placeholder,
            text: text,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: "Email address",
            accessibilityHint: "Enter your email address",
            validation: { $0.contains("@") && $0.contains(".") },
            errorMessage: "Please enter a valid email address"
        )
    }

    /// Creates a password input field with appropriate settings
    static func password(
        label: String = "Password",
        placeholder: String = "Enter your password",
        text: Binding<String>,
        isNewPassword: Bool = false,
        accessibilityIdentifier: String? = nil,
        validation: ((String) -> Bool)? = nil,
        errorMessage: String? = nil
    ) -> FormTextField {
        FormTextField(
            label: label,
            placeholder: placeholder,
            text: text,
            isSecure: true,
            textContentType: isNewPassword ? .newPassword : .password,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: "Password",
            accessibilityHint: "Enter your password",
            validation: validation,
            errorMessage: errorMessage
        )
    }

    /// Creates a name input field with appropriate settings
    static func name(
        label: String = "Name",
        placeholder: String = "Enter your name",
        text: Binding<String>,
        textContentType: UITextContentType = .name,
        accessibilityIdentifier: String? = nil
    ) -> FormTextField {
        FormTextField(
            label: label,
            placeholder: placeholder,
            text: text,
            textContentType: textContentType,
            autocapitalization: .words,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: label,
            accessibilityHint: "Enter your \(label.lowercased())"
        )
    }
}

// MARK: - Accessibility Modifier

private struct AccessibilityModifier: ViewModifier {
    let identifier: String?
    let label: String?
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Preview

#Preview("Form Text Fields") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        FormTextField.email(text: .constant("user@example.com"))

        FormTextField.password(text: .constant("password123"))

        FormTextField.name(
            label: "First Name",
            placeholder: "Enter your first name",
            text: .constant("John"),
            textContentType: .givenName
        )

        FormTextField(
            label: "Custom Field",
            placeholder: "Enter custom text",
            text: .constant(""),
            validation: { !$0.isEmpty },
            errorMessage: "This field is required"
        )
    }
    .padding()
}
