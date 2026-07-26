import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Off-main-actor AI work for explain / generate / complete.
actor AppleIntelligenceActor {
    func answerDoubt(
        question: String,
        selectedCode: String,
        context: DSAIntelligenceContext
    ) async -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = selectedCode.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(FoundationModels)
        if SystemLanguageModel.default.availability == .available {
            do {
                let instructions = """
                You are a patient DSA tutor inside DSA Playground (macOS).
                The playground already ships Animated* DSAKit types and per-module starters / Question Bank JSON.
                Explain using that built-in base — never suggest rewriting DSAKit or duplicating Animated* implementations.

                Grounding:
                \(context.promptBlock)

                Style: short paragraphs and bullets. Name concrete Animated* APIs when relevant.
                """
                let session = LanguageModelSession(instructions: instructions)
                let prompt = """
                Student question:
                \(q.isEmpty ? "Explain what this selected code does and how it uses the built-in \(context.moduleTitle) APIs." : q)

                Selected Swift code:
                ```swift
                \(code.isEmpty ? "// (no selection — discuss the active \(context.moduleTitle) playground and its built-in base)" : code)
                ```
                """
                let response = try await session.respond(to: prompt)
                return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return Self.localExplanation(
                    question: q,
                    selectedCode: code,
                    context: context,
                    note: "AI error: \(error.localizedDescription)"
                )
            }
        }
        #endif

        return Self.localExplanation(
            question: q,
            selectedCode: code,
            context: context,
            note: "Apple Intelligence unavailable — local tutor notes (grounded on built-in docs)"
        )
    }

    private static func localExplanation(
        question: String,
        selectedCode: String,
        context: DSAIntelligenceContext,
        note: String
    ) -> String {
        let lines = selectedCode.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = lines.count
        let mentionsAnimated = selectedCode.contains("Animated")
        var bullets: [String] = []
        bullets.append("Focus: \(context.moduleTitle) — uses playground Animated* base (already implemented).")
        bullets.append("Bootstrap: \(context.bootstrapCode)")
        if !question.isEmpty {
            bullets.append("Your question: \(question)")
        }
        if selectedCode.isEmpty {
            bullets.append("No code selected. Select lines, or ask about the built-in \(context.moduleTitle) APIs / Question Bank.")
        } else {
            bullets.append("Selection covers \(lineCount) line(s).")
            if mentionsAnimated {
                bullets.append("Uses DSAKit animated types — mutating calls emit Canvas View events when you Run.")
            } else {
                bullets.append("Tip: Prefer Animated* APIs from the built-in module so the Canvas View can animate.")
            }
            if selectedCode.contains("push(") || selectedCode.contains("pop(") {
                bullets.append("Stack ops: push top / pop top (LIFO).")
            }
            if selectedCode.contains("enqueue(") || selectedCode.contains("dequeue(") {
                bullets.append("Queue ops: enqueue back / dequeue front (FIFO).")
            }
            if selectedCode.contains("append(") || selectedCode.contains("insert(") {
                bullets.append("Growth ops change indices/links — watch Canvas + Flow.")
            }
        }
        if !context.questionBankDigest.isEmpty {
            bullets.append("Related Question Bank topics are available in the Explorer for this DSA.")
        }
        bullets.append("Tip: Run Selection to animate a snippet; AI chat shows a Canvas preview of the active run.")
        return """
        \(note)

        \(bullets.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}
