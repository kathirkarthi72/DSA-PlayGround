import Foundation

public struct PlaygroundEvent: Codable, Sendable {
    public var type: String
    public var structure: String
    public var index: Int?
    public var value: String?
    public var secondaryValue: String?
    public var highlight: [Int]
    public var nodes: [String]?
    public var message: String?
    public var meta: [String: String]?
    public var sourceLine: Int?

    public init(
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
        self.type = type
        self.structure = structure
        self.index = index
        self.value = value
        self.secondaryValue = secondaryValue
        self.highlight = highlight
        self.nodes = nodes
        self.message = message
        var merged = meta ?? [:]
        let normalizedLine = (sourceLine ?? 0) > 0 ? sourceLine : nil
        if let normalizedLine {
            merged["sourceLine"] = String(normalizedLine)
        }
        self.meta = merged.isEmpty ? nil : merged
        self.sourceLine = normalizedLine
    }
}

public final class InstanceCounter {
    public static let shared = InstanceCounter()
    private var counts: [String: Int] = [:]
    private let lock = NSLock()

    public func nextIndex(for structure: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = counts[structure] ?? 0
        let next = current + 1
        counts[structure] = next
        return next
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        counts.removeAll()
    }
}

public enum EventEmitter {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    public static func emit(_ event: PlaygroundEvent) {
        guard let data = try? encoder.encode(event),
              let line = String(data: data, encoding: .utf8) else { return }
        fputs(line + "\n", stdout)
        fflush(stdout)
        usleep(15_000)
    }

    public static func valueString<T>(_ value: T) -> String {
        String(describing: value)
    }
}
