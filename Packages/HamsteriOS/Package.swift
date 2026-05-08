// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HamsteriOS",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "HamsteriOS",
      targets: ["HamsteriOS"]),
  ],
  dependencies: [
    .package(url: "https://github.com/relatedcode/ProgressHUD.git", exact: "14.1.0"),
    .package(path: "../HamsterUIKit"),
    .package(path: "../HamsterKit"),
    .package(path: "../RimeKit"),
    .package(path: "../HamsterKeyboardKit"),
  ],
  targets: [
    .target(
      name: "HamsteriOS",
      dependencies: [
        "ProgressHUD",
        "HamsterUIKit",
        "HamsterKit",
        "HamsterKeyboardKit",
        .product(name: "RimeKit", package: "RimeKit"),
      ],
      path: "Sources",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "HamsteriOSTests",
      dependencies: ["HamsteriOS"],
      path: "Tests"),
  ])
