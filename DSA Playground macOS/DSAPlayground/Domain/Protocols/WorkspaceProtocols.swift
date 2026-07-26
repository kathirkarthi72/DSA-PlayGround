import Foundation
import Combine
import DSACore

protocol DocumentStoring: AnyObject {
    func workspace(for moduleID: String) -> ModuleWorkspace?
    func ensureWorkspace(for moduleID: String, starterCode: String) -> ModuleWorkspace
    func save(_ workspace: ModuleWorkspace)
    func allModuleIDs() -> [String]
}

@MainActor
protocol IntelligenceGenerating: AnyObject {
    var isGeneratingPublisher: AnyPublisher<Bool, Never> { get }
    func generateSwiftSolution(
        prompt: String,
        context: DSAIntelligenceContext
    ) async -> String?
    func completeSwiftCode(source: String, cursor: Int, context: DSAIntelligenceContext?) async -> String?
    func answerDoubt(
        question: String,
        selectedCode: String,
        context: DSAIntelligenceContext
    ) async -> String
}

@MainActor
protocol PlaygroundRunning: AnyObject {
    var statePublisher: AnyPublisher<PlaygroundRunState, Never> { get }
    var consolePublisher: AnyPublisher<String, Never> { get }
    var isBusy: Bool { get }
    var consoleOutput: String { get }
    var runState: PlaygroundRunState { get }
    func run(sources: [(name: String, content: String)], onEvent: @escaping (DSAEvent) -> Void) async
    func stop()
    func log(_ text: String)
}
