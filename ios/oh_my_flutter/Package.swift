// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "oh_my_flutter",
  platforms: [
    .iOS("15.0")
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
      ],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
