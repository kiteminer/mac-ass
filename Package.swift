// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MacAss", platforms: [.macOS(.v14)],
    products: [.executable(name: "MacAss", targets: ["MacAss"])],
    targets: [
        .target(name: "NotchCore"),
        .executableTarget(name: "MacAss", dependencies: ["NotchCore"]),
        .testTarget(name: "NotchCoreTests", dependencies: ["NotchCore"]),
        .testTarget(name: "MacAssTests", dependencies: ["MacAss", "NotchCore"])
    ]
)
