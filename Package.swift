// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "bgbgone-app",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.99.0"),
    ],
    targets: [
        .executableTarget(
            name: "bgbgone-app",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "BgBgOneAppTests",
            dependencies: [
                "bgbgone-app",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests"
        ),
    ]
)
