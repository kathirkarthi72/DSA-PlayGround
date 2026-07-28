import Foundation
import DSACore

struct RunPlaygroundUseCase {
    private let runner: PlaygroundRunning

    init(runner: PlaygroundRunning) {
        self.runner = runner
    }

    func execute(
        documents: [EditorDocument],
        activeDocumentID: UUID? = nil,
        onEvent: @escaping (DSAEvent) -> Void
    ) async {
        let sources = Self.packSources(documents: documents, activeDocumentID: activeDocumentID)
        guard !sources.isEmpty else { return }
        await runner.run(sources: sources, onEvent: onEvent)
    }

    /// Runs a selected snippet by temporarily overlaying it as the entrypoint body.
    func executeSelection(
        selection: String,
        supportDocuments: [EditorDocument],
        onEvent: @escaping (DSAEvent) -> Void
    ) async {
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var sources: [(name: String, content: String)] = supportDocuments
            .filter { doc in
                let nameLower = doc.name.lowercased()
                if nameLower == "tests.swift" { return false }
                return ["helpers.swift", "inbuild.swift"].contains(nameLower) || Self.isLibraryOnlySource(doc.content)
            }
            .map { (name: $0.name, content: $0.content) }

        let entry = """
        // Selection run
        \(trimmed)

        """
        sources.insert((name: "main.swift", content: entry), at: 0)
        await runner.run(sources: sources, onEvent: onEvent)
    }

    /// Active editor tab becomes `main.swift` (so Question Bank demos can run).
    /// Other tabs are included only when they look like declaration-only helpers.
    static func packSources(
        documents: [EditorDocument],
        activeDocumentID: UUID?
    ) -> [(name: String, content: String)] {
        guard !documents.isEmpty else { return [] }

        let preferred = activeDocumentID.flatMap { id in documents.first(where: { $0.id == id }) }
        let entry = documents.first(where: \.isEntrypoint)
        let mainDoc: EditorDocument
        
        let preferredName = preferred?.name.lowercased()
        if let preferred, preferredName != "helpers.swift" && preferredName != "inbuild.swift" {
            mainDoc = preferred
        } else {
            mainDoc = entry ?? preferred ?? documents[0]
        }

        var sources: [(name: String, content: String)] = [
            (name: "main.swift", content: mainDoc.content)
        ]

        for doc in documents where doc.id != mainDoc.id {
            let docNameLower = doc.name.lowercased()
            let isRequiredSupportFile = ["helpers.swift", "inbuild.swift"].contains(docNameLower)
            
            // Do not include tests.swift as a support file because it has top-level executable code (to run tests)
            // which would collide with the top-level code of the main entrypoint file.
            if docNameLower == "tests.swift" {
                continue
            }
            
            if isRequiredSupportFile || isLibraryOnlySource(doc.content) {
                let name = doc.name.hasSuffix(".swift") ? doc.name : doc.name + ".swift"
                // Avoid colliding with the synthetic main name.
                let safeName = name == "main.swift" ? "Support-\(doc.id.uuidString.prefix(8)).swift" : name
                sources.append((name: safeName, content: doc.content))
            }
        }
        return sources
    }

    /// Support files may only contain declarations (funcs/types/globals) — not executable statements.
    static func isLibraryOnlySource(_ source: String) -> Bool {
        let declarationPrefixes = [
            "import ", "func ", "class ", "struct ", "enum ", "protocol ", "extension ",
            "typealias ", "actor ", "let ", "var ", "@", "private ", "fileprivate ",
            "internal ", "public ", "open ", "final ", "indirect ", "consuming ",
            "borrowing ", "nonisolated ", "isolated ", "prefix ", "postfix ", "infix ",
            "precedencegroup ", "associatedtype ", "macro "
        ]

        for rawLine in source.components(separatedBy: .newlines) {
            let line = stripLineComment(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line == "{" || line == "}" || line == "};" { continue }
            if declarationPrefixes.contains(where: { line.hasPrefix($0) }) { continue }
            // Indented lines belong to an open declaration body.
            let leading = rawLine.prefix { $0 == " " || $0 == "\t" }
            if !leading.isEmpty { continue }
            return false
        }
        return true
    }

    private static func stripLineComment(_ line: String) -> String {
        var inString = false
        var result = ""
        var index = line.startIndex
        while index < line.endIndex {
            let ch = line[index]
            if ch == "\"" {
                inString.toggle()
                result.append(ch)
                index = line.index(after: index)
                continue
            }
            if !inString,
               ch == "/",
               line.index(after: index) < line.endIndex,
               line[line.index(after: index)] == "/" {
                break
            }
            result.append(ch)
            index = line.index(after: index)
        }
        return result
    }
}
