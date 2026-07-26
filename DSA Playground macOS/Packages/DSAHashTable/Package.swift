// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAHashTable",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSAHashTable", targets: ["DSAHashTable"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSAHashTable", dependencies: ["DSACore"])]
)
