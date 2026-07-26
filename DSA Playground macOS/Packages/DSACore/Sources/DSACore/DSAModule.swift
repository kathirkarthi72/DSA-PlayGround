import SwiftUI
import Observation

@MainActor
public protocol DSAVisualizer: AnyObject, Observable {
    associatedtype Body: View
    var caption: String { get }
    func reset()
    func apply(_ event: DSAEvent)
    @ViewBuilder func makeView() -> Body
}

public struct DSABuiltInAction: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// Appended Swift line(s) that drive the animated DSAKit APIs.
    public let snippet: String

    public init(id: String, title: String, systemImage: String, snippet: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.snippet = snippet
    }
}

@MainActor
public protocol DSAModule: Identifiable {
    var id: String { get }
    var title: String { get }
    var systemImage: String { get }
    var structureKey: String { get }
    var starterCode: String { get }
    var builtInActions: [DSABuiltInAction] { get }
    /// Declarative bootstrap line for live built-in demos (e.g. `var stack = AnimatedStack<Int>()`).
    var bootstrapCode: String { get }
    /// Common interview questions for this structure (from bundled JSON by default).
    var interviewQuestions: [InterviewQuestion] { get }
    func makeVisualizer() -> any DSAVisualizer
}

public extension DSAModule {
    var builtInActions: [DSABuiltInAction] { [] }
    var bootstrapCode: String { "" }
    var interviewQuestions: [InterviewQuestion] {
        InterviewQuestionBank.questions(forModuleID: id)
    }
}

@MainActor
public final class DSAModuleRegistry: ObservableObject {
    public private(set) var modules: [any DSAModule]

    public init(modules: [any DSAModule] = []) {
        self.modules = modules
    }

    public func register(_ module: any DSAModule) {
        modules.append(module)
    }

    public func module(id: String) -> (any DSAModule)? {
        modules.first { $0.id == id }
    }
}
