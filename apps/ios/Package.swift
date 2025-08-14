// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Jeeves",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "JeevesKit",
            targets: ["JeevesKit"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "JeevesKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloWebSocket", package: "apollo-ios"),
            ],
            path: "Sources",
            exclude: [
                "JeevesKit/GraphQL/README.md",
                "JeevesKit/Localization/README.md",
            ],
            resources: [
                .process("JeevesKit/Localization"),
                .copy("JeevesKit/GraphQL/Operations"),
            ],
        ),
        .testTarget(
            name: "JeevesKitTests",
            dependencies: [
                "JeevesKit",
            ],
            path: "Tests",
        ),
    ],
)
