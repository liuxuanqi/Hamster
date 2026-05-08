// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HamsterKeyboardKit",
  defaultLocalization: "zh-Hans",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    .library(name: "HamsterKeyboardKit", targets: ["HamsterKeyboardKit"]),
  ],
  dependencies: [
    .package(path: "../HamsterKit"),
    .package(path: "../HamsterUIKit"),
    .package(path: "../../../sime"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.16"),
  ],
  targets: [
    .target(
      name: "HamsterKeyboardKit",
      dependencies: [
        "HamsterKit",
        "HamsterUIKit",
        .product(name: "SimeEngine", package: "Sime"),
        .product(name: "SimeSession", package: "Sime"),
      ],
      path: "Sources",
      resources: [.process("Resources")]),
    .testTarget(
      name: "HamsterKeyboardKitTests",
      dependencies: [
        "HamsterKeyboardKit",
        "HamsterKit",
        "HamsterUIKit",
        "ZIPFoundation",
      ],
      path: "Tests"),
  ])
