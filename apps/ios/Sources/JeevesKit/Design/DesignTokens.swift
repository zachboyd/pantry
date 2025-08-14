/*
 DesignTokens.swift
 JeevesKit

 Comprehensive design token system providing consistent visual language
 across the JeevesKit iOS application.
 */

import SwiftUI
import UIKit

/// Central design token system for consistent visual language
public enum DesignTokens {
    // MARK: - Colors

    /// Semantic color system for consistent theming
    public enum Colors {
        /// Primary brand colors - Kitchen/Food themed
        public enum Primary {
            public static let base = Color.blue
            public static let light = Color.blue.opacity(0.3)
            public static let dark = Color.blue.opacity(0.8)
        }

        /// Secondary accent colors
        public enum Secondary {
            public static let base = Color.green
            public static let light = Color.green.opacity(0.3)
            public static let dark = Color.green.opacity(0.8)
        }

        /// Surface colors for containers and backgrounds
        public enum Surface {
            public static let primary = Colors.secondarySystemBackground()
            public static let secondary = Color(UIColor.systemGray6)
            public static let tertiary = Colors.systemBackground().opacity(0.95)
            public static let elevated: Color = Colors.systemBackground()
        }

        /// Text colors with semantic meaning
        public enum Text {
            public static let primary = Color.primary
            public static let secondary = Color.secondary
            public static let tertiary = Color.primary.opacity(0.6)
            public static let disabled = Color.primary.opacity(0.3)
            public static let inverse = Color.white
            public static let link = Color.accentColor
        }

        /// AI-specific colors
        public enum AI {
            public static let gradient = LinearGradient(
                colors: [Secondary.base, Primary.base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            public static let icon = Color.white
        }

        /// Interactive element colors
        public enum Interactive {
            public static let enabled = Primary.base
            public static let pressed = Primary.dark
            public static let disabled = Color.gray.opacity(0.3)
            public static let focus = Primary.light
        }

        /// Status and feedback colors
        public enum Status {
            public static let success = Color.green
            public static let warning = Color.orange
            public static let error = Color.red
            public static let info = Color.blue
        }

        /// Jeeves-specific colors
        public enum Jeeves {
            public static let fresh = Color.green
            public static let expiring = Color.orange
            public static let expired = Color.red
            public static let lowStock = Color.yellow
            public static let ingredient = Color.blue
            public static let recipe = Color.purple
        }

        /// Household-specific colors
        public enum Household {
            public static let member = Color.blue
            public static let organizer = Color.orange
            public static let invite = Color.purple
        }

        /// Utility for system background colors
        public static func systemBackground() -> Color {
            Color(UIColor.systemBackground)
        }

        public static func secondarySystemBackground() -> Color {
            Color(UIColor.secondarySystemBackground)
        }
    }

    // MARK: - Spacing

    /// Consistent spacing scale for layouts
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let xxxl: CGFloat = 64

        /// Component-specific spacing
        public enum Component {
            public static let cardPadding = md
            public static let sectionSpacing = lg
            public static let listItemSpacing = sm
            public static let buttonPadding = md
        }

        /// Layout-specific spacing
        public enum Layout {
            public static let screenEdge = md
            public static let betweenSections = xl
            public static let betweenCards = lg
        }
    }

    // MARK: - Typography

    /// Extended typography system building on FontStyles
    public enum Typography {
        /// Font weights for semantic use
        public enum Weight {
            public static let regular: Font.Weight = .regular
            public static let medium: Font.Weight = .medium
            public static let semibold: Font.Weight = .semibold
            public static let bold: Font.Weight = .bold
        }

        /// Semantic text styles
        public enum Semantic {
            /// For main page titles
            public static func pageTitle() -> Font {
                .system(.largeTitle, design: .default, weight: Weight.bold)
            }

            /// For section headers
            public static func sectionHeader() -> Font {
                .system(.title2, design: .default, weight: Weight.semibold)
            }

            /// For card titles
            public static func cardTitle() -> Font {
                .system(.headline, design: .default, weight: Weight.medium)
            }

            /// For body text
            public static func body() -> Font {
                .system(.body, design: .default, weight: Weight.regular)
            }

            /// For secondary text
            public static func caption() -> Font {
                .system(.caption, design: .default, weight: Weight.regular)
            }

            /// For button labels
            public static func button() -> Font {
                .system(.body, design: .default, weight: Weight.medium)
            }
        }
    }

    // MARK: - Shadows

    /// Consistent shadow system for depth and elevation
    public enum Shadows {
        /// Light shadow for subtle elevation
        public static let light = Shadow(
            color: .black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1,
        )

        /// Medium shadow for cards and modals
        public static let medium = Shadow(
            color: .black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2,
        )

        /// Heavy shadow for floating elements
        public static let heavy = Shadow(
            color: .black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4,
        )
    }

    // MARK: - Border Radius

    /// Consistent border radius scale
    public enum BorderRadius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let round: CGFloat = 50 // For circular elements

        /// Component-specific radius
        public enum Component {
            public static let button = sm
            public static let card = md
            public static let avatar = round
        }
    }

    // MARK: - Animation

    /// Consistent animation timing and curves
    public enum Animation {
        /// Animation durations
        public enum Duration {
            public static let fast: Double = 0.2
            public static let normal: Double = 0.3
            public static let slow: Double = 0.5
        }

        /// Animation curves
        public enum Curve {
            public static let easeOut = SwiftUI.Animation.easeOut(duration: Duration.normal)
            public static let spring = SwiftUI.Animation.spring(
                response: 0.6,
                dampingFraction: 0.8,
                blendDuration: 0,
            )
        }

        /// Component-specific animations
        public enum Component {
            public static let buttonPress = SwiftUI.Animation.easeOut(duration: Duration.fast)
            public static let sheetPresentation = Curve.spring
            public static let listItemAppear = Curve.easeOut
        }
    }

    // MARK: - Component Sizes

    /// Standard component sizing
    public enum ComponentSize {
        /// Avatar sizes
        public enum Avatar {
            public static let small: CGFloat = 24
            public static let medium: CGFloat = 32
            public static let large: CGFloat = 48
            public static let extraLarge: CGFloat = 64
        }

        /// Button sizes
        public enum Button {
            public static let small: CGFloat = 32
            public static let medium: CGFloat = 44
            public static let large: CGFloat = 56
        }

        /// Icon sizes
        public enum Icon {
            public static let small: CGFloat = 16
            public static let medium: CGFloat = 24
            public static let large: CGFloat = 32
        }

        /// Touch target minimum sizes (for accessibility)
        public enum TouchTarget {
            public static let minimum: CGFloat = 44
        }
    }
}

/// Custom shadow definition for design tokens
public struct Shadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}
