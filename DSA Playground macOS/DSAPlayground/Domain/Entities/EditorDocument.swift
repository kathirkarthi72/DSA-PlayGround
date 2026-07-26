import Foundation

struct EditorDocument: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var name: String
    var content: String
    /// Compiled as `main.swift` (top-level entry). Other tabs are support files.
    var isEntrypoint: Bool

    init(
        id: UUID = UUID(),
        name: String,
        content: String = "",
        isEntrypoint: Bool = false
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.isEntrypoint = isEntrypoint
    }
}

struct CodeDiagnostic: Identifiable, Equatable, Hashable, Sendable {
    enum Severity: String, Sendable {
        case error
        case warning
    }

    let id: UUID
    var severity: Severity
    var documentID: UUID
    var line: Int
    var column: Int
    var message: String
    var suggestion: String
    /// If set, Accept replaces the whole line (1-based) with this text.
    var fixLineText: String?
    /// If set, Accept replaces the entire document content.
    var fixDocumentText: String?

    init(
        id: UUID = UUID(),
        severity: Severity,
        documentID: UUID,
        line: Int,
        column: Int = 1,
        message: String,
        suggestion: String,
        fixLineText: String? = nil,
        fixDocumentText: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.documentID = documentID
        self.line = line
        self.column = column
        self.message = message
        self.suggestion = suggestion
        self.fixLineText = fixLineText
        self.fixDocumentText = fixDocumentText
    }

    var hasFix: Bool {
        fixLineText != nil || fixDocumentText != nil
    }
}

struct FoldRegion: Identifiable, Hashable, Sendable {
    let id: UUID
    var startLine: Int
    var endLine: Int
    var placeholder: String
    var foldedContent: String

    init(id: UUID = UUID(), startLine: Int, endLine: Int, placeholder: String, foldedContent: String) {
        self.id = id
        self.startLine = startLine
        self.endLine = endLine
        self.placeholder = placeholder
        self.foldedContent = foldedContent
    }
}

/// Per-DSA playground workspace (files belonging to one structure).
struct ModuleWorkspace: Identifiable, Equatable, Sendable {
    var id: String
    var documents: [EditorDocument]
    var activeDocumentID: UUID
    var foldedRegions: [UUID: [FoldRegion]]

    init(
        id: String,
        documents: [EditorDocument],
        activeDocumentID: UUID? = nil,
        foldedRegions: [UUID: [FoldRegion]] = [:]
    ) {
        self.id = id
        self.documents = documents
        self.activeDocumentID = activeDocumentID ?? documents.first?.id ?? UUID()
        self.foldedRegions = foldedRegions
    }

    var activeDocument: EditorDocument? {
        documents.first(where: { $0.id == activeDocumentID })
    }
}
