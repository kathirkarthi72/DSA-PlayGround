import Foundation

public struct AnimatedQueue<Element> {
    private var storage: [Element] = []
    private let name: String

    public init(name: String? = nil, line: Int = #line) {
        let actualName = name ?? "Queue \(InstanceCounter.shared.nextIndex(for: "queue"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "queue",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["name": actualName],
            sourceLine: line
        ))
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    public mutating func enqueue(_ value: Element, line: Int = #line) {
        storage.append(value)
        EventEmitter.emit(PlaygroundEvent(
            type: "enqueue",
            structure: "queue",
            index: storage.count - 1,
            value: EventEmitter.valueString(value),
            highlight: [storage.count - 1],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Enqueue \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    @discardableResult
    public mutating func dequeue(line: Int = #line) -> Element? {
        guard !storage.isEmpty else {
            EventEmitter.emit(PlaygroundEvent(
                type: "dequeue",
                structure: "queue",
                nodes: [],
                message: "\(name): Dequeue (empty)",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let value = storage.removeFirst()
        EventEmitter.emit(PlaygroundEvent(
            type: "dequeue",
            structure: "queue",
            value: EventEmitter.valueString(value),
            highlight: storage.isEmpty ? [] : [0],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Dequeue \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }

    public func peek(line: Int = #line) -> Element? {
        guard let value = storage.first else {
            EventEmitter.emit(PlaygroundEvent(
                type: "peek",
                structure: "queue",
                nodes: [],
                message: "\(name): Peek (empty)",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "peek",
            structure: "queue",
            index: 0,
            value: EventEmitter.valueString(value),
            highlight: [0],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Peek \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }
}
