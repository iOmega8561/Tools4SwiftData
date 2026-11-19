// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Tools4SwiftData",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Tools4SwiftData",
            targets: ["Tools4SwiftData"]),
    ],
    dependencies: [
        // swift-syntax ships one major version per Swift release: a wide range
        // lets clients resolve it together with other macro packages.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"603.0.0")
    ],
    targets: [
        .macro(
            name: "Tools4SwiftDataMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "Tools4SwiftData",
            dependencies: ["Tools4SwiftDataMacros"]
        ),
        .testTarget(
            name: "Tools4SwiftDataMacrosTests",
            dependencies: [
                "Tools4SwiftDataMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
