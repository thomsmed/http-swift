// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HTTPSwift",
    platforms: [
        .macOS(.v13),
        .tvOS(.v16),
        .visionOS(.v1),
        .iOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "HTTP",
            targets: ["HTTP"]),
    ],
    targets: [
        .target(
            name: "HTTP"
        ),
        .testTarget(
            name: "HTTPTests",
            dependencies: ["HTTP"]
        ),

        .target(
            name: "Examples",
            dependencies: ["HTTP"]
        ),
        .testTarget(
            name: "ExamplesTests",
            dependencies: ["Examples"]
        ),
    ]
)
