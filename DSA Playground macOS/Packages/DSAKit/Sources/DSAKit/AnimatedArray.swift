import Foundation

public struct AnimatedArray<Element> {
    private var storage: [Element] = []
    private let name: String

    public init(name: String? = nil, line: Int = #line) {
        let actualName = name ?? "Array \(InstanceCounter.shared.nextIndex(for: "array"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "array",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["name": actualName],
            sourceLine: line
        ))
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    public mutating func append(_ value: Element, line: Int = #line) {
        storage.append(value)
        EventEmitter.emit(PlaygroundEvent(
            type: "append",
            structure: "array",
            index: storage.count - 1,
            value: EventEmitter.valueString(value),
            highlight: [storage.count - 1],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Append \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    public mutating func insert(_ value: Element, at index: Int, line: Int = #line) {
        let clamped = max(0, min(index, storage.count))
        storage.insert(value, at: clamped)
        EventEmitter.emit(PlaygroundEvent(
            type: "insert",
            structure: "array",
            index: clamped,
            value: EventEmitter.valueString(value),
            highlight: [clamped],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Insert \(EventEmitter.valueString(value)) at \(clamped)",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    @discardableResult
    public mutating func remove(at index: Int, line: Int = #line) -> Element? {
        guard storage.indices.contains(index) else {
            EventEmitter.emit(PlaygroundEvent(
                type: "remove",
                structure: "array",
                index: index,
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Remove failed (invalid index \(index))",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let value = storage.remove(at: index)
        EventEmitter.emit(PlaygroundEvent(
            type: "remove",
            structure: "array",
            index: index,
            value: EventEmitter.valueString(value),
            highlight: [],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Remove \(EventEmitter.valueString(value)) at \(index)",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }

    public func at(_ index: Int, line: Int = #line) -> Element? {
        guard storage.indices.contains(index) else {
            EventEmitter.emit(PlaygroundEvent(
                type: "access",
                structure: "array",
                index: index,
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Access failed (invalid index \(index))",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let value = storage[index]
        EventEmitter.emit(PlaygroundEvent(
            type: "access",
            structure: "array",
            index: index,
            value: EventEmitter.valueString(value),
            highlight: [index],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Access index \(index) → \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }

    public subscript(index: Int) -> Element? {
        at(index, line: 0)
    }
}
