// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacAutoHotkey",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "macahk", targets: ["MacAutoHotkey"])
    ],
    targets: [
        .executableTarget(
            name: "MacAutoHotkey",
            path: "Sources/MacAutoHotkey"
        )
    ]
)
