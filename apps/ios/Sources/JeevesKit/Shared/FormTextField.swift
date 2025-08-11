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
    let font: Font?
    let autoFocus: Bool
    let lineLimit: ClosedRange<Int>?

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
        errorMessage: String? = nil,
        font: Font? = nil,
        autoFocus: Bool = false,
        lineLimit: ClosedRange<Int>? = nil
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
        self.font = font
        self.autoFocus = autoFocus
        self.lineLimit = lineLimit
    }

    public var body: some View {
        let horizontalPadding = DesignTokens.Spacing.lg
        let verticalPadding = DesignTokens.Spacing.md
        // Calculate corner radius based on font size and vertical padding
        // Default to body font if no custom font is provided
        let effectiveFont = font ?? DesignTokens.Typography.Semantic.body()
        let cornerRadius = calculateCornerRadius(for: effectiveFont, verticalPadding: verticalPadding)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Label
            Text(label)
                .font(DesignTokens.Typography.Semantic.caption())
                .foregroundColor(hasError ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Text.secondary)
                .padding(.horizontal, horizontalPadding)

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
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .cornerRadius(cornerRadius)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            // Error message - always present to avoid layout shifts
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignTokens.Typography.Semantic.caption())
                    .foregroundColor(DesignTokens.Colors.Status.error)
                    .padding(.leading, horizontalPadding)
                    .opacity(hasError ? 1.0 : 0.0)
            }
        }
        .onAppear {
            if autoFocus {
                // Small delay to ensure the view is fully rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
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
                    .font(font)
                    .frame(minHeight: 22) // Ensure consistent height
            } else if isSecure && isPasswordVisible {
                // Password field in visible mode - use regular TextField
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(font)
                    .frame(minHeight: 22) // Ensure consistent height
            } else if let lineLimit = lineLimit {
                // Multi-line TextField with axis parameter
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .font(font)
                    .lineLimit(lineLimit)
            } else {
                // Single-line TextField
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .font(font)
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

    /// Calculates the corner radius based on the font size and vertical padding
    /// Returns a value that considers both the text size and the container's vertical padding
    /// - Parameters:
    ///   - font: The font used in the text field
    ///   - verticalPadding: Optional vertical padding to include in the calculation
    private func calculateCornerRadius(for font: Font, verticalPadding: CGFloat? = nil) -> CGFloat {
        // Extract font size from the Font if possible
        // SwiftUI doesn't expose font metrics directly, so we need to estimate

        // Check if it's a system font with a specific size
        let fontSize: CGFloat

        // Since SwiftUI's Font doesn't expose its size directly,
        // we'll use UIFont to get the default sizes for text styles
        switch font {
        case .largeTitle:
            fontSize = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        case .title:
            fontSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
        case .title2:
            fontSize = UIFont.preferredFont(forTextStyle: .title2).pointSize
        case .title3:
            fontSize = UIFont.preferredFont(forTextStyle: .title3).pointSize
        case .headline:
            fontSize = UIFont.preferredFont(forTextStyle: .headline).pointSize
        case .body:
            fontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        case .callout:
            fontSize = UIFont.preferredFont(forTextStyle: .callout).pointSize
        case .subheadline:
            fontSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        case .footnote:
            fontSize = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        case .caption:
            fontSize = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        case .caption2:
            fontSize = UIFont.preferredFont(forTextStyle: .caption2).pointSize
        default:
            // For custom fonts or system fonts with specific sizes,
            // default to a standard body size
            fontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        }

        // Calculate the total height of the input field
        // This includes the font size plus vertical padding (top and bottom)
        let effectivePadding = verticalPadding ?? 0
        let totalHeight = fontSize + (effectivePadding * 2)

        // The corner radius should be proportional to the total height
        // Using half the height would create a pill shape
        // Using a smaller ratio creates a more subtle rounded corner
        let cornerRadiusRatio: CGFloat = 0.6 // Adjust this for more or less rounding (0.3-0.6 works well)

        // Ensure a minimum corner radius for very small fields
        let minimumRadius: CGFloat = 8.0

        // Calculate the corner radius based on total height
        let calculatedRadius = totalHeight * cornerRadiusRatio

        // Return the larger of the calculated radius or minimum
        return max(calculatedRadius, minimumRadius)
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
