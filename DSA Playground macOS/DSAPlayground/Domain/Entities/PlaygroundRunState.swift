import Foundation

enum PlaygroundRunState: Equatable, Sendable {
    case idle
    case compiling
    case running
    case failed
    case finished
}
