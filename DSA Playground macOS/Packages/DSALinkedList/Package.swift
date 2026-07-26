// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSALinkedList",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DSALinkedList", targets: ["DSALinkedList"])],
    dependencies: [.package(path: "../DSACore")],
    targets: [.target(name: "DSALinkedList", dependencies: ["DSACore"])]
)
