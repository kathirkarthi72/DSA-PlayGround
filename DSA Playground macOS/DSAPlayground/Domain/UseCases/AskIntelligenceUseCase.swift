import Foundation

struct AskIntelligenceUseCase {
    private let intelligence: IntelligenceGenerating

    init(intelligence: IntelligenceGenerating) {
        self.intelligence = intelligence
    }

    func execute(
        question: String,
        selectedCode: String,
        context: DSAIntelligenceContext
    ) async -> AIMessage {
        let answer = await intelligence.answerDoubt(
            question: question,
            selectedCode: selectedCode,
            context: context
        )
        return AIMessage(
            role: .assistant,
            content: answer,
            selectedCode: selectedCode.isEmpty ? nil : selectedCode
        )
    }
}
