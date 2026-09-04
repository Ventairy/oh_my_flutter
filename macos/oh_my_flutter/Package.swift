// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "oh_my_flutter",
  platforms: [
    .macOS("12.0")
  ],
  products: [
    .library(name: "oh-my-flutter", targets: ["oh_my_flutter"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "oh_my_flutter",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    ),
    .testTarget(
      name: "oh_my_flutterTests",
      dependencies: ["oh_my_flutter"]
    ),
  ]
)
