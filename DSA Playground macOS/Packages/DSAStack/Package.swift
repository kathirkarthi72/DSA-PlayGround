// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAStack",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSAStack", targets: ["DSAStack"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSAStack", dependencies: ["DSACore"])]
)
