import Foundation

enum DiagnosticsEngine {
    /// Fast local checks + optional `swiftc -parse` syntax diagnostics.
    static func analyze(document: EditorDocument, allDocuments: [EditorDocument]) -> [CodeDiagnostic] {
        var diagnostics: [CodeDiagnostic] = []
        diagnostics.append(contentsOf: localChecks(document: document))
        diagnostics.append(contentsOf: parseSyntax(document: document))
        return diagnostics.sorted { lhs, rhs in
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            return lhs.severity == .error && rhs.severity != .error
        }
    }

    private static func localChecks(document: EditorDocument) -> [CodeDiagnostic] {
        var result: [CodeDiagnostic] = []
        let lines = document.content.components(separatedBy: .newlines)
        let text = document.content

        // Unbalanced delimiters
        let pairs: [(Character, Character, String)] = [
            ("(", ")", "parentheses"),
            ("{", "}", "braces"),
            ("[", "]", "brackets")
        ]
        for (open, close, name) in pairs {
            let opens = text.filter { $0 == open }.count
            let closes = text.filter { $0 == close }.count
            if opens > closes {
                result.append(CodeDiagnostic(
                    severity: .error,
                    documentID: document.id,
                    line: max(1, lines.count),
                    message: "Unbalanced \(name): missing \(closes == opens - 1 ? "'\(close)'" : "\(opens - closes) '\(close)'")",
                    suggestion: "Add \(opens - closes) closing \(name) at the end.",
                    fixDocumentText: text + String(repeating: String(close), count: opens - closes) + "\n"
                ))
            } else if closes > opens {
                result.append(CodeDiagnostic(
                    severity: .warning,
                    documentID: document.id,
                    line: max(1, lines.count),
                    message: "Extra closing \(name) detected.",
                    suggestion: "Remove extra '\(close)' characters."
                ))
            }
        }

        for (index, line) in lines.enumerated() {
            let lineNo = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("Stack<"), !trimmed.contains("AnimatedStack") {
                let fixed = line.replacingOccurrences(of: "Stack<", with: "AnimatedStack<")
                result.append(CodeDiagnostic(
                    severity: .warning,
                    documentID: document.id,
                    line: lineNo,
                    message: "Use AnimatedStack for playground visualization.",
                    suggestion: "Replace Stack with AnimatedStack.",
                    fixLineText: fixed
                ))
            }
            if trimmed.contains("Queue<"), !trimmed.contains("AnimatedQueue") {
                let fixed = line.replacingOccurrences(of: "Queue<", with: "AnimatedQueue<")
                result.append(CodeDiagnostic(
                    severity: .warning,
                    documentID: document.id,
                    line: lineNo,
                    message: "Use AnimatedQueue for playground visualization.",
                    suggestion: "Replace Queue with AnimatedQueue.",
                    fixLineText: fixed
                ))
            }
            if let _ = trimmed.range(of: #"\bimport\s+DSAKit\b"#, options: .regularExpression) {
                result.append(CodeDiagnostic(
                    severity: .warning,
                    documentID: document.id,
                    line: lineNo,
                    message: "`import DSAKit` is not needed in the playground.",
                    suggestion: "Remove this import line.",
                    fixLineText: ""
                ))
            }
            if trimmed.hasPrefix("print(") {
                result.append(CodeDiagnostic(
                    severity: .warning,
                    documentID: document.id,
                    line: lineNo,
                    message: "print() output mixes with visualization event JSON.",
                    suggestion: "Prefer Animated* APIs so operations animate on the right."
                ))
            }
            // Common typo
            if trimmed.contains("aniamted") || trimmed.contains("Animted") {
                let fixed = line
                    .replacingOccurrences(of: "aniamted", with: "Animated", options: .caseInsensitive)
                    .replacingOccurrences(of: "Animted", with: "Animated")
                result.append(CodeDiagnostic(
                    severity: .error,
                    documentID: document.id,
                    line: lineNo,
                    message: "Possible typo in Animated type name.",
                    suggestion: "Correct spelling to Animated…",
                    fixLineText: fixed
                ))
            }
        }

        if document.isEntrypoint,
           !text.contains("Animated"),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(CodeDiagnostic(
                severity: .warning,
                documentID: document.id,
                line: 1,
                message: "No Animated* structure found in entry file.",
                suggestion: "Create an AnimatedStack / AnimatedQueue / etc. so Run can visualize changes."
            ))
        }

        return result
    }

    private static func parseSyntax(document: EditorDocument) -> [CodeDiagnostic] {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("DSAPlaygroundLint-\(document.id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        // Always parse as main.swift so Question Bank tabs (top-level statements) lint cleanly.
        let fileURL = temp.appendingPathComponent("main.swift")
        do {
            try document.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return []
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc", "-parse", fileURL.path]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = stderr.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        try? FileManager.default.removeItem(at: temp)
        return parseCompilerOutput(text, documentID: document.id)
    }

    static func parseCompilerOutput(_ output: String, documentID: UUID) -> [CodeDiagnostic] {
        var diagnostics: [CodeDiagnostic] = []
        // path:line:column: error: message
        let pattern = #"([^:\n]+):(\d+):(\d+):\s+(error|warning):\s+(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = output as NSString
        regex.enumerateMatches(in: output, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match,
                  match.numberOfRanges >= 6,
                  let line = Int(ns.substring(with: match.range(at: 2))),
                  let column = Int(ns.substring(with: match.range(at: 3))) else { return }
            let severityRaw = ns.substring(with: match.range(at: 4))
            let message = ns.substring(with: match.range(at: 5))
            let severity: CodeDiagnostic.Severity = severityRaw == "warning" ? .warning : .error
            let suggestion: String
            if message.contains("expected ')'") {
                suggestion = "Add a closing parenthesis ')'."
            } else if message.contains("expected '}'") {
                suggestion = "Add a closing brace '}'."
            } else if message.contains("cannot find") {
                suggestion = "Check the symbol name or create the Animated* type first."
            } else if message.contains("extraneous") {
                suggestion = "Remove the unexpected token."
            } else {
                suggestion = "Review this line and fix the Swift syntax/type issue."
            }
            diagnostics.append(CodeDiagnostic(
                severity: severity,
                documentID: documentID,
                line: line,
                column: column,
                message: message,
                suggestion: suggestion
            ))
        }
        return diagnostics
    }

    static func applyFix(_ diagnostic: CodeDiagnostic, to content: String) -> String? {
        if let full = diagnostic.fixDocumentText {
            return full
        }
        guard let lineText = diagnostic.fixLineText else { return nil }
        var lines = content.components(separatedBy: .newlines)
        let index = diagnostic.line - 1
        guard lines.indices.contains(index) else { return nil }
        if lineText.isEmpty {
            lines.remove(at: index)
        } else {
            lines[index] = lineText
        }
        return lines.joined(separator: "\n")
    }
}
