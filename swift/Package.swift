// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacropadBinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacropadBinder",
            path: "Sources/MacropadBinder",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
