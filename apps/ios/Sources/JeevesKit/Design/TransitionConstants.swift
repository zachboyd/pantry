//
//  TransitionConstants.swift
//  JeevesKit
//
//  Created on 2025.
//

import SwiftUI

/// Constants for app-wide transitions and animations
public enum TransitionConstants {
    // MARK: - Phase Transition Durations

    /// Duration for fading out the previous screen
    public static let fadeOutDuration: Double = 0.3

    /// Duration for fading in the new screen
    public static let fadeInDuration: Double = 0.4

    /// Total transition duration (for overlapping transitions)
    public static let totalTransitionDuration: Double = 0.5

    /// Delay before starting fade in (creates a smoother transition)
    public static let fadeInDelay: Double = 0.1

    // MARK: - Specific Screen Transitions

    /// Launch screen to authentication transition
    public static let launchToAuthDuration: Double = 0.6

    /// Authentication to main app transition
    public static let authToMainDuration: Double = 0.5

    /// Onboarding transitions
    public static let onboardingStepDuration: Double = 0.4

    /// Error screen transition
    public static let errorTransitionDuration: Double = 0.3

    // MARK: - Household Switching Animation

    /// Duration for the blur effect when switching households
    public static let householdSwitchBlurDuration: Double = 0.3

    /// Duration for the slide animation when switching households
    public static let householdSwitchSlideDuration: Double = 0.5

    /// Duration for the scale animation when switching households
    public static let householdSwitchScaleDuration: Double = 0.2

    /// Scale factor when switching households (0.9 = 90%)
    public static let householdSwitchScaleFactor: Double = 0.9

    // MARK: - Animation Curves

    /// Standard easing curve for transitions
    public static func standardEasing(duration: Double) -> Animation {
        Animation.easeInOut(duration: duration)
    }

    /// Gentle easing for subtle transitions
    public static func gentleEasing(duration: Double) -> Animation {
        Animation.easeOut(duration: duration)
    }

    /// Spring animation for interactive elements
    public static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Smooth spring for view transitions
    public static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)

    // MARK: - Opacity Values

    /// Starting opacity for fade in
    public static let fadeInStartOpacity: Double = 0.0

    /// Ending opacity for fade in
    public static let fadeInEndOpacity: Double = 1.0

    /// Background dim opacity
    public static let backgroundDimOpacity: Double = 0.3

    // MARK: - Helper Methods

    /// Creates a fade transition with standard timing
    public static func fadeTransition(duration: Double = totalTransitionDuration) -> AnyTransition {
        .opacity.animation(standardEasing(duration: duration))
    }

    /// Creates a combined fade and scale transition
    public static func fadeAndScaleTransition(duration: Double = totalTransitionDuration) -> AnyTransition {
        AnyTransition.opacity.combined(with: .scale(scale: 0.95))
            .animation(standardEasing(duration: duration))
    }

    /// Creates a slide and fade transition
    public static func slideAndFadeTransition(edge: Edge = .trailing, duration: Double = totalTransitionDuration) -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity,
        )
        .animation(standardEasing(duration: duration))
    }

    /// Creates a gentle push transition for navigation-like animations
    public static func pushTransition(duration: Double = totalTransitionDuration) -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity),
        )
        .animation(gentleEasing(duration: duration))
    }
}

// MARK: - View Extensions

public extension View {
    /// Applies a standard fade transition to the view
    func fadeTransition() -> some View {
        transition(TransitionConstants.fadeTransition())
    }

    /// Applies a fade transition with custom duration
    func fadeTransition(duration: Double) -> some View {
        transition(TransitionConstants.fadeTransition(duration: duration))
    }

    /// Applies fade and scale transition
    func fadeAndScaleTransition() -> some View {
        transition(TransitionConstants.fadeAndScaleTransition())
    }

    /// Applies slide and fade transition
    func slideAndFadeTransition(edge: Edge = .trailing) -> some View {
        transition(TransitionConstants.slideAndFadeTransition(edge: edge))
    }

    /// Applies push transition for navigation-like animations
    func pushTransition() -> some View {
        transition(TransitionConstants.pushTransition())
    }

    /// Applies a gentle animation to value changes
    func gentleAnimation(value: some Equatable) -> some View {
        animation(TransitionConstants.gentleEasing(duration: TransitionConstants.totalTransitionDuration), value: value)
    }
}
