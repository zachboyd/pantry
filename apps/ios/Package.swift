// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Jeeves",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "JeevesKit",
            targets: ["JeevesKit"]
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
            name: "JeevesKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloWebSocket", package: "apollo-ios"),
                "CASLSwift"
            ],
            path: "Sources",
            exclude: [
                "JeevesKit/GraphQL/README.md",
                "JeevesKit/Localization/README.md",
                "CASLSwift"
            ],
            resources: [
                .process("JeevesKit/Localization"),
                .copy("JeevesKit/GraphQL/Operations")
            ]
        ),
        .testTarget(
            name: "JeevesKitTests",
            dependencies: [
                "JeevesKit"
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