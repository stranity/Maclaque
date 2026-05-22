// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Maclaque",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MaclaqueDaemon", targets: ["MaclaqueDaemon"]),
        .executable(name: "Maclaque", targets: ["Maclaque"]),
    ],
    targets: [
        // C wrapper for IOKit HID accelerometer (Apple Silicon)
        .target(
            name: "CHIDAccelerometer",
            path: "Sources/CHIDAccelerometer",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),

        // Daemon — runs as root, reads accelerometer, sends events via Unix socket
        .executableTarget(
            name: "MaclaqueDaemon",
            dependencies: ["CHIDAccelerometer"],
            path: "Sources/MaclaqueDaemon",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),

        // Main app — SwiftUI menu bar app (user space)
        .executableTarget(
            name: "Maclaque",
            path: "Sources/Maclaque",
            resources: [
                .copy("../../Resources/Packs"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        ),

        // Tests
        .testTarget(
            name: "MaclaqueTests",
            dependencies: ["MaclaqueDaemon"],
            path: "Tests/MaclaqueTests"
        ),
    ]
)
