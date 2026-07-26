import Foundation

/// Composer mode for the right-side Apple Intelligence panel.
enum AIAssistantMode: String, CaseIterable, Identifiable, Sendable, Hashable {
    case ask
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return "Ask"
        case .agent: return "Agent"
        }
    }

    var systemImage: String {
        switch self {
        case .ask: return "questionmark.bubble"
        case .agent: return "hammer.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .ask: return "Ask about this code or DSA…"
        case .agent: return "Describe code to generate…"
        }
    }

    var submitTitle: String {
        switch self {
        case .ask: return "Ask"
        case .agent: return "Generate"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .ask: return "Ask about your code"
        case .agent: return "Generate playground code"
        }
    }

    var emptyStateDetail: String {
        switch self {
        case .ask:
            return "Explain selections, clear doubts, and learn how the built-in Animated* APIs work for this DSA."
        case .agent:
            return "Describe a problem and Agent will generate Swift into the active entry file, reusing this module’s Animated* types."
        }
    }
}

enum AIMessageRole: String, Sendable, Hashable {
    case user
    case assistant
    case system
}

struct AIMessage: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var role: AIMessageRole
    var content: String
    var selectedCode: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: AIMessageRole,
        content: String,
        selectedCode: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.selectedCode = selectedCode
        self.createdAt = createdAt
    }
}
