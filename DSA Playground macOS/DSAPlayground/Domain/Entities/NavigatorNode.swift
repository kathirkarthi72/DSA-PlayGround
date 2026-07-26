import Foundation

/// Hierarchical DSA file-navigator node (module folder or Swift file).
enum NavigatorNode: Identifiable, Hashable, Sendable {
    case module(id: String, title: String, systemImage: String, files: [NavigatorFile])
    case file(NavigatorFile)

    var id: String {
        switch self {
        case .module(let id, _, _, _):
            return "module:\(id)"
        case .file(let file):
            return "file:\(file.moduleID):\(file.documentID.uuidString)"
        }
    }
}

struct NavigatorFile: Identifiable, Hashable, Sendable {
    var id: UUID { documentID }
    let moduleID: String
    let documentID: UUID
    let name: String
    let isEntrypoint: Bool
}
