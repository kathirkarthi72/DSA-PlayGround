// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSATree",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSATree", targets: ["DSATree"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSATree", dependencies: ["DSACore"])]
)
