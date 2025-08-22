/*
 GoogleIcon.swift
 JeevesKit

 Official Google "G" icon for Sign In button
 */

import SwiftUI
import UIKit

/// Official Google "G" icon for authentication
public struct GoogleIcon: View {
    let size: CGFloat

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        // Load from bundle directly, bypassing asset catalog
        if let bundleURL = Bundle.module.url(forResource: "google-G", withExtension: "png"),
           let imageData = try? Data(contentsOf: bundleURL),
           let uiImage = UIImage(data: imageData)
        {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

#Preview("Google Icon") {
    VStack(spacing: 20) {
        GoogleIcon(size: 50)
        GoogleIcon(size: 30)
        GoogleIcon(size: 20)
    }
    .padding()
}
