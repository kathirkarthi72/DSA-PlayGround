import Foundation
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AppleIntelligenceGenerator: ObservableObject, IntelligenceGenerating {
    enum Status: Equatable {
        case idle
        case generating
        case unavailable(String)
        case failed(String)
        case ready
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSource: String = ""

    private let aiActor = AppleIntelligenceActor()

    var isGenerating: Bool {
        if case .generating = status { return true }
        return false
    }

    var isGeneratingPublisher: AnyPublisher<Bool, Never> {
        $status.map { status in
            if case .generating = status { return true }
            return false
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var availabilityMessage: String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return "Apple Intelligence ready"
        case .unavailable(.deviceNotEligible):
            return "This Mac is not eligible for Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Enable Apple Intelligence in System Settings"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence model is still downloading"
        default:
            return "Apple Intelligence unavailable"
        }
        #else
        return "FoundationModels framework not available in this SDK"
        #endif
    }

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
    }

    func generateSwiftSolution(
        prompt: String,
        context: DSAIntelligenceContext
    ) async -> String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = .failed("Enter a problem prompt first.")
            return nil
        }

        status = .generating

        #if canImport(FoundationModels)
        if SystemLanguageModel.default.availability == .available {
            do {
                let code = try await generateWithFoundationModels(prompt: trimmed, context: context)
                let cleaned = Self.deduplicateAgainstBase(
                    code: Self.extractSwiftCode(from: code),
                    context: context
                )
                lastSource = "Apple Intelligence"
                status = .ready
                return cleaned
            } catch {
                let fallback = Self.deduplicateAgainstBase(
                    code: Self.localScaffold(prompt: trimmed, context: context),
                    context: context
                )
                lastSource = "Local scaffold (AI error: \(error.localizedDescription))"
                status = .ready
                return fallback
            }
        }
        #endif

        let fallback = Self.deduplicateAgainstBase(
            code: Self.localScaffold(prompt: trimmed, context: context),
            context: context
        )
        lastSource = "Local scaffold (\(availabilityMessage))"
        status = .unavailable(availabilityMessage)
        return fallback
    }

    #if canImport(FoundationModels)
    private func generateWithFoundationModels(
        prompt: String,
        context: DSAIntelligenceContext
    ) async throws -> String {
        let instructions = """
        You write Swift ONLY for DSA Playground’s existing Animated* APIs.
        The playground already implements all DSA base types and visualization — never regenerate that infrastructure.

        \(context.promptBlock)

        Hard requirements:
        - Output ONLY top-level Swift (no markdown fences, no prose).
        - Reuse \(context.bootstrapCode.isEmpty ? "the active module bootstrap" : context.bootstrapCode) — declare the structure at most once.
        - Do not create new Stack/Queue/Tree/Heap classes; call Animated* methods only.
        - Do not duplicate helpers, imports, or boilerplate already in the current editor source.
        - Prefer a short demo that animates the algorithm with concrete values.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: """
        Solve this problem for the \(context.moduleTitle) Canvas View using the built-in base code above.
        Return a complete runnable top-level Swift file that does NOT reimplement DSAKit.

        Problem:
        \(prompt)
        """)
        return response.content
    }
    #endif

    func answerDoubt(
        question: String,
        selectedCode: String,
        context: DSAIntelligenceContext
    ) async -> String {
        status = .generating
        let answer = await aiActor.answerDoubt(
            question: question,
            selectedCode: selectedCode,
            context: context
        )
        lastSource = isAvailable ? "Apple Intelligence" : "Local tutor"
        status = .ready
        return answer
    }

    /// Short inline / next-line completion at the cursor for the code editor.
    func completeSwiftCode(
        source: String,
        cursor: Int,
        context: DSAIntelligenceContext? = nil
    ) async -> String? {
        guard isAvailable else { return nil }

        let before = String(source.prefix(max(0, cursor)))
        let after = String(source.dropFirst(max(0, cursor)))
        let beforeWindow = String(before.suffix(500))
        let afterWindow = String(after.prefix(200))

        #if canImport(FoundationModels)
        do {
            let grounding = context.map {
                    """
                    Prefer existing DSA Playground APIs for \($0.moduleTitle):
                    \($0.bootstrapCode)
                    \($0.apiHints)
                    Do not invent duplicate types.
                    """
                } ?? "Prefer DSAKit Animated* types already linked in the playground."

                let instructions = """
                You are a Swift code-completion engine for DSA Playground.
                Return ONLY the text that should be inserted at the cursor.
                No markdown, no explanation, no quotes around the answer.
                \(grounding)
                Keep completions short (usually under 80 characters, at most 2 lines).
                Continue naturally from the cursor position.
                """
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: """
                Complete at <CURSOR>.

                CODE BEFORE:
                \(beforeWindow)<CURSOR>\(afterWindow)
                """)
                var text = Self.extractSwiftCode(from: response.content)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 180 {
                    text = String(text.prefix(180))
                }
                if before.hasSuffix(text) { return nil }
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        #endif
        return nil
    }

    static func extractSwiftCode(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fence = text.range(of: "```") {
            text = String(text[fence.upperBound...])
            if text.lowercased().hasPrefix("swift") {
                text = String(text.dropFirst(5))
            }
            if let end = text.range(of: "```") {
                text = String(text[..<end.lowerBound])
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// Drop regenerated DSAKit types / duplicate bootstrap lines.
    static func deduplicateAgainstBase(code: String, context: DSAIntelligenceContext) -> String {
        let bannedTypeDefs = [
            "struct Animated", "class Animated", "enum Animated",
            "public struct Animated", "public class Animated", "public final class Animated",
            "final class Animated"
        ]
        var kept: [String] = []
        var skippingTypeBody = false
        var braceDepth = 0
        var sawBootstrap = false
        let bootstrap = context.bootstrapCode
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for raw in code.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if skippingTypeBody {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count
                if braceDepth <= 0 {
                    skippingTypeBody = false
                    braceDepth = 0
                }
                continue
            }

            if bannedTypeDefs.contains(where: { trimmed.hasPrefix($0) }) {
                skippingTypeBody = trimmed.contains("{")
                braceDepth = trimmed.filter { $0 == "{" }.count - trimmed.filter { $0 == "}" }.count
                if braceDepth <= 0 { skippingTypeBody = false }
                continue
            }

            if trimmed.hasPrefix("import DSAKit") || trimmed.hasPrefix("import SwiftUI") || trimmed.hasPrefix("import UIKit") {
                continue
            }

            if bootstrap.contains(trimmed) {
                if sawBootstrap || context.existingSource.contains(trimmed) {
                    continue
                }
                sawBootstrap = true
            }

            kept.append(raw)
        }

        var result = kept.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure bootstrap exists once when the file would otherwise lack an Animated* declaration.
        if !context.bootstrapCode.isEmpty,
           !result.contains("Animated"),
           !result.contains(context.bootstrapCode) {
            result = context.bootstrapCode + "\n\n" + result
        }

        return result + "\n"
    }

    static func localScaffold(prompt: String, context: DSAIntelligenceContext) -> String {
        let comment = prompt
            .split(separator: "\n")
            .prefix(6)
            .map { "// \($0)" }
            .joined(separator: "\n")

        let bootstrap = context.bootstrapCode
        let demo: String
        switch context.structureKey {
        case "stack":
            demo = """
            \(bootstrap)
            stack.push(1)
            stack.push(2)
            stack.push(3)
            _ = stack.peek()
            _ = stack.pop()
            """
        case "queue":
            demo = """
            \(bootstrap)
            queue.enqueue(1)
            queue.enqueue(2)
            queue.enqueue(3)
            _ = queue.dequeue()
            """
        case "array":
            demo = """
            \(bootstrap)
            array.append(10)
            array.append(20)
            array.insert(15, at: 1)
            _ = array.at(1)
            _ = array.remove(at: 0)
            """
        case "linkedList":
            demo = """
            \(bootstrap)
            list.append(1)
            list.append(2)
            list.prepend(0)
            list.traverse()
            """
        case "hashTable":
            demo = """
            \(bootstrap)
            table.put("a", 1)
            table.put("b", 2)
            _ = table.get("a")
            _ = table.remove("b")
            """
        case "heap":
            demo = """
            \(bootstrap)
            heap.insert(40)
            heap.insert(10)
            heap.insert(25)
            _ = heap.extract()
            """
        case "tree":
            demo = """
            \(bootstrap)
            tree.insert(50)
            tree.insert(30)
            tree.insert(70)
            _ = tree.search(30)
            tree.traverseInorder()
            """
        default:
            demo = bootstrap
        }

        return """
        // \(context.moduleTitle) — grounded on built-in DSA Playground APIs
        \(comment)
        // Uses existing Animated* types (not reimplemented).

        \(demo)
        """
    }
}
