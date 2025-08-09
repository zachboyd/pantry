// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CASLSwift",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "CASLSwift",
            targets: ["CASLSwift"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CASLSwift",
            dependencies: [],
            path: ".",
            exclude: [
                "README.md",
                "Documentation",
                "Examples",
                "Serialization/PermissionFormat.md"
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
        .testTarget(
            name: "CASLSwiftTests",
            dependencies: ["CASLSwift"],
            path: "Tests"
        )
    ]
)