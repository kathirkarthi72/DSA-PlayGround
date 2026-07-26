// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "DSAKit", targets: ["DSAKit"])
    ],
    targets: [
        .target(name: "DSAKit")
    ]
)
