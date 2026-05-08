// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HamsterKit",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "HamsterKit",
      targets: ["HamsterKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.16"),
  ],
  targets: [
    .target(
      name: "HamsterKit",
      dependencies: [
        "ZIPFoundation",
      ],
      path: "Sources"),
    .testTarget(
      name: "HamsterKitTests",
      dependencies: ["HamsterKit"],
      path: "Tests"),
  ])
