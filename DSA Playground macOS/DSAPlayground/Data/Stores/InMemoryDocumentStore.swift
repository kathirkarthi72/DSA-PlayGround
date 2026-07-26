import Foundation

/// In-memory per-DSA document store (Data layer).
final class InMemoryDocumentStore: DocumentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var workspaces: [String: ModuleWorkspace] = [:]

    func workspace(for moduleID: String) -> ModuleWorkspace? {
        lock.lock()
        defer { lock.unlock() }
        return workspaces[moduleID]
    }

    func ensureWorkspace(for moduleID: String, starterCode: String) -> ModuleWorkspace {
        lock.lock()
        defer { lock.unlock() }
        if let existing = workspaces[moduleID] {
            return existing
        }
        let main = EditorDocument(name: "main.swift", content: starterCode, isEntrypoint: true)
        let helpers = EditorDocument(
            name: "Helpers.swift",
            content: """
            // Shared helpers for this DSA playground (compiled with main.swift)
            // Example:
            // func demoValues() -> [Int] { [1, 2, 3] }

            """,
            isEntrypoint: false
        )
        let workspace = ModuleWorkspace(id: moduleID, documents: [main, helpers])
        workspaces[moduleID] = workspace
        return workspace
    }

    func save(_ workspace: ModuleWorkspace) {
        lock.lock()
        defer { lock.unlock() }
        workspaces[workspace.id] = workspace
    }

    func allModuleIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(workspaces.keys)
    }
}
