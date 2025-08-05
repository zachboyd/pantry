/*
 DeviceType.swift
 PantryKit

 Device type detection for iPad-responsive layouts
 */

import SwiftUI

/// Device type detection utilities
public enum DeviceType: Sendable {
    case iPhone
    case iPad

    /// Current device type
    public static var current: DeviceType {
        return MainActor.assumeIsolated {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return .iPad
            } else {
                return .iPhone
            }
        }
    }

    /// Whether the current device is iPad
    public static var isiPad: Bool {
        current == .iPad
    }

    /// Whether the current device is iPhone
    public static var isiPhone: Bool {
        current == .iPhone
    }
}

/// Size class utilities for responsive design
public struct SizeClassInfo: Sendable {
    let horizontal: UserInterfaceSizeClass?
    let vertical: UserInterfaceSizeClass?

    /// Whether the interface is compact (iPhone portrait, iPad split view)
    public var isCompact: Bool {
        horizontal == .compact
    }

    /// Whether the interface is regular (iPad, iPhone landscape)
    public var isRegular: Bool {
        horizontal == .regular
    }

    /// Whether this is a split view scenario (regular width, compact height on iPad)
    public var isSplitView: Bool {
        horizontal == .regular && vertical == .compact
    }
}

/// Environment key for size class info
struct SizeClassInfoKey: EnvironmentKey {
    static let defaultValue = SizeClassInfo(horizontal: nil, vertical: nil)
}

public extension EnvironmentValues {
    var sizeClassInfo: SizeClassInfo {
        get { self[SizeClassInfoKey.self] }
        set { self[SizeClassInfoKey.self] = newValue }
    }
}

/// View modifier to inject size class information
public struct SizeClassInfoModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    public func body(content: Content) -> some View {
        content
            .environment(\.sizeClassInfo, SizeClassInfo(
                horizontal: horizontalSizeClass,
                vertical: verticalSizeClass
            ))
    }
}

public extension View {
    /// Apply size class information to the view hierarchy
    func withSizeClassInfo() -> some View {
        modifier(SizeClassInfoModifier())
    }
}
