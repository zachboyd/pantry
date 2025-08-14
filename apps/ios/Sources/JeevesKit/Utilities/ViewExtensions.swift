/*
 ViewExtensions.swift
 JeevesKit

 Common view extensions and modifiers for SwiftUI views
 */

import SwiftUI

// MARK: - View Extensions

public extension View {
    /// Conditionally applies a modifier to a view based on a condition
    /// This allows for cleaner conditional view modifications without if-else statements
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello")
    ///     .conditionalModifier { view in
    ///         if isLargeText {
    ///             view.font(.largeTitle)
    ///         } else {
    ///             view.font(.body)
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter transform: A closure that takes the view and returns a modified version
    /// - Returns: The modified view
    func conditionalModifier(@ViewBuilder transform: (Self) -> some View) -> some View {
        transform(self)
    }

    /// Applies a modifier only when a condition is true
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello")
    ///     .modifier(if: showBorder) { view in
    ///         view.border(Color.red, width: 2)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - transform: The modifier to apply if the condition is true
    /// - Returns: The view with or without the modification
    @ViewBuilder
    func modifier(
        if condition: Bool,
        @ViewBuilder transform: (Self) -> some View,
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies one of two modifiers based on a condition
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello")
    ///     .modifier(
    ///         if: isEnabled,
    ///         then: { $0.foregroundColor(.blue) },
    ///         else: { $0.foregroundColor(.gray) }
    ///     )
    /// ```
    ///
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - thenTransform: The modifier to apply if the condition is true
    ///   - elseTransform: The modifier to apply if the condition is false
    /// - Returns: The view with the appropriate modification
    @ViewBuilder
    func modifier(
        if condition: Bool,
        @ViewBuilder then thenTransform: (Self) -> some View,
        @ViewBuilder else elseTransform: (Self) -> some View,
    ) -> some View {
        if condition {
            thenTransform(self)
        } else {
            elseTransform(self)
        }
    }
}
