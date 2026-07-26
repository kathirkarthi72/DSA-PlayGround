import Foundation

public struct AnimatedHeap<Element: Comparable> {
    public enum Kind: String {
        case min
        case max
    }

    private var storage: [Element] = []
    private let kind: Kind
    private let name: String

    public init(kind: Kind = .min, name: String? = nil, line: Int = #line) {
        self.kind = kind
        let actualName = name ?? "Heap \(InstanceCounter.shared.nextIndex(for: "heap"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "heap",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["kind": kind.rawValue, "name": actualName],
            sourceLine: line
        ))
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    private func shouldOrderBefore(_ a: Element, _ b: Element) -> Bool {
        kind == .min ? a < b : a > b
    }

    public mutating func insert(_ value: Element, line: Int = #line) {
        storage.append(value)
        let index = storage.count - 1
        EventEmitter.emit(PlaygroundEvent(
            type: "insert",
            structure: "heap",
            index: index,
            value: EventEmitter.valueString(value),
            highlight: [index],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Insert \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        heapifyUp(from: index, line: line)
    }

    @discardableResult
    public mutating func extract(line: Int = #line) -> Element? {
        guard let first = storage.first else {
            EventEmitter.emit(PlaygroundEvent(
                type: "extract",
                structure: "heap",
                nodes: [],
                message: "\(name): Extract (empty)",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let last = storage.removeLast()
        if storage.isEmpty {
            EventEmitter.emit(PlaygroundEvent(
                type: "extract",
                structure: "heap",
                value: EventEmitter.valueString(first),
                nodes: [],
                message: "\(name): Extract \(EventEmitter.valueString(first))",
                meta: ["name": name],
                sourceLine: line
            ))
            return first
        }
        storage[0] = last
        EventEmitter.emit(PlaygroundEvent(
            type: "extract",
            structure: "heap",
            index: 0,
            value: EventEmitter.valueString(first),
            highlight: [0],
            nodes: storage.map(EventEmitter.valueString),
            message: "\(name): Extract \(EventEmitter.valueString(first))",
            meta: ["name": name],
            sourceLine: line
        ))
        heapifyDown(from: 0, line: line)
        return first
    }

    private mutating func heapifyUp(from index: Int, line: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            EventEmitter.emit(PlaygroundEvent(
                type: "compare",
                structure: "heap",
                index: child,
                value: EventEmitter.valueString(storage[child]),
                secondaryValue: EventEmitter.valueString(storage[parent]),
                highlight: [child, parent],
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Compare \(EventEmitter.valueString(storage[child])) with parent \(EventEmitter.valueString(storage[parent]))",
                meta: ["name": name],
                sourceLine: line
            ))
            guard shouldOrderBefore(storage[child], storage[parent]) else { break }
            storage.swapAt(child, parent)
            EventEmitter.emit(PlaygroundEvent(
                type: "swap",
                structure: "heap",
                index: child,
                highlight: [child, parent],
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Swap \(child) ↔ \(parent)",
                meta: ["other": String(parent), "name": name],
                sourceLine: line
            ))
            child = parent
        }
    }

    private mutating func heapifyDown(from index: Int, line: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent
            if left < storage.count {
                EventEmitter.emit(PlaygroundEvent(
                    type: "compare",
                    structure: "heap",
                    index: left,
                    highlight: [parent, left],
                    nodes: storage.map(EventEmitter.valueString),
                    message: "\(name): Compare with left child",
                    meta: ["name": name],
                    sourceLine: line
                ))
                if shouldOrderBefore(storage[left], storage[candidate]) {
                    candidate = left
                }
            }
            if right < storage.count {
                EventEmitter.emit(PlaygroundEvent(
                    type: "compare",
                    structure: "heap",
                    index: right,
                    highlight: [parent, right],
                    nodes: storage.map(EventEmitter.valueString),
                    message: "\(name): Compare with right child",
                    meta: ["name": name],
                    sourceLine: line
                ))
                if shouldOrderBefore(storage[right], storage[candidate]) {
                    candidate = right
                }
            }
            if candidate == parent { break }
            storage.swapAt(parent, candidate)
            EventEmitter.emit(PlaygroundEvent(
                type: "swap",
                structure: "heap",
                index: parent,
                highlight: [parent, candidate],
                nodes: storage.map(EventEmitter.valueString),
                message: "\(name): Swap \(parent) ↔ \(candidate)",
                meta: ["other": String(candidate), "name": name],
                sourceLine: line
            ))
            parent = candidate
        }
    }
}
