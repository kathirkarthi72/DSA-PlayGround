import Foundation

public struct DSAEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var type: String
    public var structure: String
    public var index: Int?
    public var value: String?
    public var secondaryValue: String?
    public var highlight: [Int]
    public var nodes: [String]?
    public var message: String?
    public var meta: [String: String]?
    /// 1-based line number in the student `main.swift` that produced this event.
    public var sourceLine: Int?

    public init(
        id: UUID = UUID(),
        type: String,
        structure: String,
        index: Int? = nil,
        value: String? = nil,
        secondaryValue: String? = nil,
        highlight: [Int] = [],
        nodes: [String]? = nil,
        message: String? = nil,
        meta: [String: String]? = nil,
        sourceLine: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.structure = structure
        self.index = index
        self.value = value
        self.secondaryValue = secondaryValue
        self.highlight = highlight
        self.nodes = nodes
        self.message = message
        self.meta = meta
        if let sourceLine {
            self.sourceLine = sourceLine
        } else if let raw = meta?["sourceLine"], let parsed = Int(raw) {
            self.sourceLine = parsed
        } else {
            self.sourceLine = nil
        }
    }

    public var caption: String {
        if let message, !message.isEmpty { return message }
        let valueText = value.map { " \($0)" } ?? ""
        let indexText = index.map { " at \($0)" } ?? ""
        return "\(type.capitalized)\(valueText)\(indexText)"
    }

    /// Short teaching note for Canvas View / flow panel.
    public var hint: String {
        if let metaHint = meta?["hint"], !metaHint.isEmpty { return metaHint }
        let valueText = value.map { "“\($0)”" } ?? "a value"
        let indexText = index.map { " at index \($0)" } ?? ""
        switch type.lowercased() {
        case "push", "enqueue", "append":
            return "Adding \(valueText) to the structure\(indexText). Watch how the top/front/end moves."
        case "insert", "set", "put":
            return "Inserting \(valueText)\(indexText). Later elements may shift or rehash."
        case "pop", "dequeue", "remove", "delete":
            return "Removing \(valueText)\(indexText). Observe the new boundary element."
        case "peek", "access", "get", "front", "top":
            return "Reading \(valueText) without mutating the structure."
        case "search", "find", "contains", "lookup":
            return "Searching for \(valueText). Follow comparisons / hash bucket probes."
        case "swap", "siftup", "siftdown", "heapify":
            return "Reordering elements to restore the heap / balance invariant."
        case "rotate", "reverse":
            return "Rearranging existing nodes — structure size stays the same."
        case "highlight", "compare", "visit":
            return "Highlighting the nodes involved in this algorithm step."
        default:
            if let message, !message.isEmpty {
                return "What happened: \(message)"
            }
            return "Executing \(type) on \(structure)."
        }
    }
}
