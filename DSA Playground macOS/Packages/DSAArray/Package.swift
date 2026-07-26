// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAArray",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSAArray", targets: ["DSAArray"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSAArray", dependencies: ["DSACore"])]
)
