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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.23.0")
    ],
    targets: [
        .target(
            name: "PantryKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloWebSocket", package: "apollo-ios")
            ],
            path: "Sources",
            exclude: [
                "PantryKit/GraphQL/README.md",
                "PantryKit/Localization/README.md"
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
        )
    ]
)