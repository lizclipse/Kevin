// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "kevin",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    //        .package(url: "https://github.com/SwiftcordApp/DiscordKit", branch: "main"),
    .package(path: "../DiscordKit"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    .package(url: "https://github.com/gonzalezreal/DefaultCodable.git", from: "1.2.1"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "kevin",
      dependencies: [
        .product(name: "DiscordKitBot", package: "DiscordKit"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "DefaultCodable", package: "DefaultCodable"),
      ],
      path: "Sources"
    )
  ],
  swiftLanguageModes: [.v6]
)
