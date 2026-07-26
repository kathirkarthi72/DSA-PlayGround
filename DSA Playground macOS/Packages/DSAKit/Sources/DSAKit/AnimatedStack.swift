import Foundation

public struct AnimatedStack<Element> {
    private var storage: [Element] = []
    private let name: String

    public init(name: String? = nil, line: Int = #line) {
        let actualName = name ?? "Stack \(InstanceCounter.shared.nextIndex(for: "stack"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "stack",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["name": actualName],
            sourceLine: line
        ))
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    public mutating func push(_ value: Element, line: Int = #line) {
        storage.append(value)
        EventEmitter.emit(PlaygroundEvent(
            type: "push",
            structure: "stack",
            index: storage.count - 1,
            value: EventEmitter.valueString(value),
            highlight: [storage.count - 1],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Push \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    @discardableResult
    public mutating func pop(line: Int = #line) -> Element? {
        guard let value = storage.popLast() else {
            EventEmitter.emit(PlaygroundEvent(
                type: "pop",
                structure: "stack",
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Pop (empty)",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "pop",
            structure: "stack",
            value: EventEmitter.valueString(value),
            highlight: storage.isEmpty ? [] : [storage.count - 1],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Pop \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }

    public func peek(line: Int = #line) -> Element? {
        guard let value = storage.last else {
            EventEmitter.emit(PlaygroundEvent(
                type: "peek",
                structure: "stack",
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Peek (empty)",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "peek",
            structure: "stack",
            index: storage.count - 1,
            value: EventEmitter.valueString(value),
            highlight: [storage.count - 1],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Peek \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }
}
