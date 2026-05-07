// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "RimeKit",
  platforms: [
    .iOS(.v15),
    .macOS(.v13),
  ],
  products: [
    .library(name: "RimeKit", targets: ["RimeKit"]),
  ],
  dependencies: [
    .package(path: "../HamsterKit"),
    .package(path: "../../../sime"),
  ],
  targets: [
    .target(
      name: "RimeKit",
      dependencies: [
        "HamsterKit",
        .product(name: "SimeEngine", package: "Sime"),
        .product(name: "SimeSession", package: "Sime"),
      ],
      path: "Sources/Swift"),
    .testTarget(
      name: "RimeKitTests",
      dependencies: ["RimeKit"]),
  ])
