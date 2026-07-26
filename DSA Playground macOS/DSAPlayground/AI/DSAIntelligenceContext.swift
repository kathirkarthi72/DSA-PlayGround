import Foundation
import DSACore

/// Grounding pack for Apple Intelligence — knows the playground’s existing DSA base code.
struct DSAIntelligenceContext: Sendable {
    let moduleID: String
    let moduleTitle: String
    let structureKey: String
    let bootstrapCode: String
    let starterCode: String
    let apiHints: String
    let questionBankDigest: String
    let existingSource: String
    let documentation: String

    /// Compact prompt block injected into generate / ask / complete calls.
    var promptBlock: String {
        """
        # DSA Playground — built-in base (DO NOT reimplement)

        \(documentation)

        ## Active module
        - Title: \(moduleTitle)
        - ID / structureKey: \(moduleID) / \(structureKey)
        - Bootstrap (already provided by the playground — reuse, do not redefine types):
        ```swift
        \(bootstrapCode)
        ```
        - Built-in action snippets (prefer these APIs):
        ```swift
        \(apiHints.isEmpty ? "// (no built-in actions)" : apiHints)
        ```

        ## Module starter sample (reference style only)
        ```swift
        \(starterCode)
        ```

        ## Interview Question Bank (topics already covered in-app)
        \(questionBankDigest.isEmpty ? "- (none loaded)" : questionBankDigest)

        ## Current editor source (avoid duplicating what is already here)
        ```swift
        \(existingSource.isEmpty ? "// empty file" : existingSource)
        ```
        """
    }

    static func documentationGuide() -> String {
        """
        DSA Playground is a macOS learning app. Student code runs as top-level Swift and animates via DSAKit.

        ## Already implemented Animated* types (linked — never rewrite these classes)
        - AnimatedArray: append, insert(_:at:), remove(at:), at(_:)
        - AnimatedLinkedList: append, prepend, insert(_:at:), remove(at:), traverse
        - AnimatedStack: push, pop, peek
        - AnimatedQueue: enqueue, dequeue, peek
        - AnimatedHashTable: put, get, remove (capacity initializer)
        - AnimatedHeap: insert, extract (kind: .min / .max)
        - AnimatedBinaryTree: insert, search, delete, traverseInorder

        ## Rules for generated Swift
        1. Use ONLY the Animated* APIs above for mutations you want visualized.
        2. Do NOT invent Stack/Queue/List wrappers, and do NOT paste DSAKit source.
        3. Do NOT `import DSAKit` / UIKit / SwiftUI / Foundation networking.
        4. Prefer the active module’s bootstrap line; declare the structure once.
        5. Demonstrate with concrete values so Canvas View can animate each step.
        6. If the editor already contains a working bootstrap + demo, extend it — do not duplicate declarations.
        7. Output top-level executable Swift only (no markdown fences, no commentary outside // comments).

        ## Product layout (from in-app docs)
        Explorer (DSA picker, Files, Question Bank) · Editor · Canvas View · Apple Intelligence · Console/Flow.
        Question Bank JSON lives under QuestionBank/{module}/{id}.json with description + swiftCode.
        """
    }
}

@MainActor
enum DSAIntelligenceContextBuilder {
    static func make(
        module: any DSAModule,
        existingSource: String
    ) -> DSAIntelligenceContext {
        let actions = module.builtInActions
        let apiHints = actions.map { action in
            "// \(action.title): \(action.snippet)"
        }.joined(separator: "\n")

        let questions = module.interviewQuestions.prefix(8).map { q in
            "- \(q.title) [\(q.difficulty)]: \(q.summary)"
        }.joined(separator: "\n")

        return DSAIntelligenceContext(
            moduleID: module.id,
            moduleTitle: module.title,
            structureKey: module.structureKey,
            bootstrapCode: module.bootstrapCode,
            starterCode: module.starterCode,
            apiHints: apiHints,
            questionBankDigest: questions,
            existingSource: String(existingSource.prefix(4_000)),
            documentation: DSAIntelligenceContext.documentationGuide()
        )
    }
}
