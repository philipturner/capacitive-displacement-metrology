// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SerialInterface",
    platforms: [
      .macOS(.v15),
    ],
    dependencies: [
      .package(
        url: "https://github.com/pvieito/PythonKit",
        branch: "master"),
      .package(
        url: "https://github.com/christophhagen/SwiftSerial",
        branch: "master"),
    ],
    targets: [
      .executableTarget(
        name: "SerialInterface",
        dependencies: [
          "PythonKit",
          "SwiftSerial",
        ]
      ),
    ]
)
