/*
 LoadingAnimations.swift
 PantryKit

 Professional loading animations and transitions for the Pantry app
 */

import SwiftUI

// MARK: - Enhanced Loading Views

/// Enhanced loading view with smooth animations
public struct EnhancedLoadingView: View {
    let message: String
    let showLogo: Bool

    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    @State private var opacity: Double = 0.7

    public init(message: String = "Loading...", showLogo: Bool = true) {
        self.message = message
        self.showLogo = showLogo
    }

    public var body: some View {
        VStack(spacing: 24) {
            if showLogo {
                // Animated logo
                Image(systemName: "\(AppSections.emptyStateIcon(for: .pantry)).fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.blue.gradient)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            scale = 1.1
                        }
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                Text(L("app.name"))
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            // Animated loading indicator
            HStack(spacing: 8) {
                ForEach(0 ..< 3) { index in
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 8, height: 8)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: scale
                        )
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: opacity
                        )
                }
            }
            .onAppear {
                withAnimation {
                    scale = 1.5
                    opacity = 1.0
                }
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Skeleton Loading Views

/// Skeleton view for loading list items
public struct SkeletonListItemView: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Avatar skeleton
                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .shimmer(isAnimating: isAnimating)

                VStack(alignment: .leading, spacing: 4) {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                        .frame(height: 16)
                        .shimmer(isAnimating: isAnimating)

                    // Subtitle skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 120, height: 12)
                        .shimmer(isAnimating: isAnimating)
                }

                Spacer()

                // Action skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 60, height: 16)
                    .shimmer(isAnimating: isAnimating)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            isAnimating = true
        }
    }
}

/// Skeleton view for loading cards
public struct SkeletonCardView: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 100, height: 20)
                    .shimmer(isAnimating: isAnimating)

                Spacer()

                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .shimmer(isAnimating: isAnimating)
            }

            // Content skeleton
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(height: 16)
                    .shimmer(isAnimating: isAnimating)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 16)
                    .shimmer(isAnimating: isAnimating)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 150, height: 16)
                    .shimmer(isAnimating: isAnimating)
            }

            // Footer skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 80, height: 14)
                    .shimmer(isAnimating: isAnimating)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 60, height: 14)
                    .shimmer(isAnimating: isAnimating)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Transition Views

/// Smooth transition view for state changes
public struct StateTransitionView<Content: View>: View {
    let content: Content
    let isVisible: Bool

    public init(isVisible: Bool, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isVisible = isVisible
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

/// Pull-to-refresh indicator
public struct PullToRefreshView: View {
    let isRefreshing: Bool
    let progress: Double

    public init(isRefreshing: Bool, progress: Double = 0) {
        self.isRefreshing = isRefreshing
        self.progress = progress
    }

    public var body: some View {
        VStack {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(progress > 0.8 ? 180 : 0))
                    .scaleEffect(max(0.5, progress))
                    .opacity(progress)
            }
        }
        .frame(height: 40)
        .animation(.easeInOut(duration: 0.3), value: isRefreshing)
        .animation(.easeOut(duration: 0.2), value: progress)
    }
}

// MARK: - Success/Error Animations

/// Success animation view
public struct SuccessAnimationView: View {
    @State private var checkmarkScale: Double = 0
    @State private var circleScale: Double = 0
    @State private var opacity: Double = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.green.gradient)
                .scaleEffect(circleScale)
                .opacity(opacity * 0.3)

            Circle()
                .stroke(.green, lineWidth: 2)
                .scaleEffect(circleScale)
                .opacity(opacity)

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.green)
                .scaleEffect(checkmarkScale)
                .opacity(opacity)
        }
        .frame(width: 60, height: 60)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                circleScale = 1.0
                opacity = 1.0
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) {
                checkmarkScale = 1.0
            }
        }
    }
}

/// Error animation view
public struct ErrorAnimationView: View {
    @State private var xScale: Double = 0
    @State private var circleScale: Double = 0
    @State private var opacity: Double = 0
    @State private var shake: Double = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.red.gradient)
                .scaleEffect(circleScale)
                .opacity(opacity * 0.3)

            Circle()
                .stroke(.red, lineWidth: 2)
                .scaleEffect(circleScale)
                .opacity(opacity)

            // X mark
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.red)
                .scaleEffect(xScale)
                .opacity(opacity)
        }
        .frame(width: 60, height: 60)
        .offset(x: shake)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                circleScale = 1.0
                opacity = 1.0
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) {
                xScale = 1.0
            }

            // Shake animation
            withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true).delay(0.5)) {
                shake = 5
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Shimmer effect for skeleton loading
    func shimmer(isAnimating: Bool) -> some View {
        overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(x: isAnimating ? 1 : 0.01, anchor: .leading)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .clipped()
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Smooth content transition
    func contentTransition() -> some View {
        transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    /// Smooth scale transition
    func scaleTransition() -> some View {
        transition(.scale.combined(with: .opacity))
    }
}
