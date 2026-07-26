// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSAHeap",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSAHeap", targets: ["DSAHeap"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSAHeap", dependencies: ["DSACore"])]
)
