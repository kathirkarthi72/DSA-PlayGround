// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSACore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "DSACore", targets: ["DSACore"])
    ],
    targets: [
        .target(
            name: "DSACore"
        )
    ]
)
