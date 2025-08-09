// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pantry",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "PantryKit",
            targets: ["PantryKit"]
        ),
        .library(
            name: "CASLSwift",
            targets: ["CASLSwift"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.23.0")
    ],
    targets: [
        .target(
            name: "CASLSwift",
            dependencies: [],
            path: "Sources/CASLSwift",
            exclude: [
                "Serialization/PermissionFormat.md",
                "README.md",
                "Examples",
                "Tests",
                "Package.swift"
            ],
            sources: [
                "Core",
                "Conditions",
                "Rules",
                "Builders",
                "Extensions",
                "Serialization"
            ]
        ),
        .target(
            name: "PantryKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloWebSocket", package: "apollo-ios"),
                "CASLSwift"
            ],
            path: "Sources",
            exclude: [
                "PantryKit/GraphQL/README.md",
                "PantryKit/Localization/README.md",
                "CASLSwift"
            ],
            resources: [
                .process("PantryKit/Localization"),
                .copy("PantryKit/GraphQL/Operations")
            ]
        ),
        .testTarget(
            name: "PantryKitTests",
            dependencies: [
                "PantryKit"
            ],
            path: "Tests"
        ),
        .testTarget(
            name: "CASLSwiftTests",
            dependencies: ["CASLSwift"],
            path: "Sources/CASLSwift/Tests"
        )
    ]
)