// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "JarvisCore",
    products: [.library(name: "JarvisCore", targets: ["JarvisCore"])],
    targets: [
        .target(name: "JarvisCore", path: "Sources/Core"),
        .testTarget(name: "JarvisCoreTests", dependencies: ["JarvisCore"], path: "Tests/JarvisCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
