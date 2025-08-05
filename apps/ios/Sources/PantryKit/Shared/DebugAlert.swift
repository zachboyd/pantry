/*
 DebugAlert.swift
 PantryKit

 Debug-enabled alert modifier that adds auth clearing functionality
 */

import SwiftUI

public extension View {
    /// Shows an alert with optional debug controls in DEBUG builds
    func debugAlert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        primaryButton: String = "OK",
        onPrimaryAction: (() -> Void)? = nil,
        includeDebugOptions: Bool = true
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button(primaryButton) {
                onPrimaryAction?()
            }
            
            #if DEBUG
            if includeDebugOptions {
                Button("Clear Auth Data", role: .destructive) {
                    clearAuthDataAndRestart()
                }
            }
            #endif
        } message: {
            if let message = message {
                Text(message)
            }
        }
    }
    
    /// Shows an error alert with debug controls in DEBUG builds
    func errorAlert(
        isPresented: Binding<Bool>,
        error: String?,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert("Error", isPresented: isPresented) {
            Button("OK") {
                onDismiss?()
            }
            
            #if DEBUG
            Button("Clear Auth Data", role: .destructive) {
                clearAuthDataAndRestart()
            }
            #endif
        } message: {
            if let error = error {
                Text(error)
            }
        }
    }
}

#if DEBUG
private func clearAuthDataAndRestart() {
    // Clear all auth data
    KeychainHelper.clearAllAuthData()
    
    // Force app to restart/refresh
    Task { @MainActor in
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(
                rootView: AppRootView()
                    .withAppState()
            )
        }
    }
}
#endif