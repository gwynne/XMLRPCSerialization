// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "XMLRPCSerialization",
    products: [
        .library(
            name: "XMLRPCSerialization",
            targets: ["XMLRPCSerialization"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "XMLRPCSerialization",
            dependencies: []),
        .testTarget(
            name: "XMLRPCSerializationTests",
            dependencies: ["XMLRPCSerialization"]),
    ]
)
