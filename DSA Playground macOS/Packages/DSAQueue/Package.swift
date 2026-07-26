// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAQueue",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSAQueue", targets: ["DSAQueue"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSAQueue", dependencies: ["DSACore"])]
)
