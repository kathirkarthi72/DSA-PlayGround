import Foundation

public final class AnimatedLinkedList<Element> {
    private final class Node {
        var value: Element
        var next: Node?
        init(_ value: Element) { self.value = value }
    }

    private var head: Node?
    private var countStorage = 0
    private let name: String

    public init(name: String? = nil, line: Int = #line) {
        let actualName = name ?? "List \(InstanceCounter.shared.nextIndex(for: "linkedList"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "linkedList",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["name": actualName],
            sourceLine: line
        ))
    }

    public var count: Int { countStorage }
    public var isEmpty: Bool { head == nil }

    private func snapshot() -> [String] {
        var values: [String] = []
        var current = head
        while let node = current {
            values.append(EventEmitter.valueString(node.value))
            current = node.next
        }
        return values
    }

    public func append(_ value: Element, line: Int = #line) {
        let node = Node(value)
        if head == nil {
            head = node
        } else {
            var current = head
            while let next = current?.next {
                current = next
            }
            current?.next = node
        }
        countStorage += 1
        let nodes = snapshot()
        EventEmitter.emit(PlaygroundEvent(
            type: "append",
            structure: "linkedList",
            index: nodes.count - 1,
            value: EventEmitter.valueString(value),
            highlight: [nodes.count - 1],
            nodes: nodes,
            message: "\(name): Append \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    public func prepend(_ value: Element, line: Int = #line) {
        let node = Node(value)
        node.next = head
        head = node
        countStorage += 1
        let nodes = snapshot()
        EventEmitter.emit(PlaygroundEvent(
            type: "prepend",
            structure: "linkedList",
            index: 0,
            value: EventEmitter.valueString(value),
            highlight: [0],
            nodes: nodes,
            message: "\(name): Prepend \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    public func insert(_ value: Element, at index: Int, line: Int = #line) {
        if index <= 0 {
            prepend(value, line: line)
            return
        }
        if index >= countStorage {
            append(value, line: line)
            return
        }
        var current = head
        var i = 0
        while i < index - 1, let node = current {
            current = node.next
            i += 1
        }
        let node = Node(value)
        node.next = current?.next
        current?.next = node
        countStorage += 1
        let nodes = snapshot()
        EventEmitter.emit(PlaygroundEvent(
            type: "insert",
            structure: "linkedList",
            index: index,
            value: EventEmitter.valueString(value),
            highlight: [index],
            nodes: nodes,
            message: "\(name): Insert \(EventEmitter.valueString(value)) at \(index)",
            meta: ["name": name],
            sourceLine: line
        ))
    }

    @discardableResult
    public func remove(at index: Int, line: Int = #line) -> Element? {
        guard index >= 0, index < countStorage, let headNode = head else {
            EventEmitter.emit(PlaygroundEvent(
                type: "remove",
                structure: "linkedList",
                index: index,
                nodes: snapshot(),
                message: "\(name): Remove failed (invalid index \(index))",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let removed: Element
        if index == 0 {
            removed = headNode.value
            head = headNode.next
        } else {
            var current = head
            var i = 0
            while i < index - 1, let node = current {
                current = node.next
                i += 1
            }
            guard let target = current?.next else { return nil }
            removed = target.value
            current?.next = target.next
        }
        countStorage -= 1
        EventEmitter.emit(PlaygroundEvent(
            type: "remove",
            structure: "linkedList",
            index: index,
            value: EventEmitter.valueString(removed),
            highlight: [],
            nodes: snapshot(),
            message: "\(name): Remove \(EventEmitter.valueString(removed)) at \(index)",
            meta: ["name": name],
            sourceLine: line
        ))
        return removed
    }

    public func traverse(line: Int = #line) {
        let nodes = snapshot()
        for (index, value) in nodes.enumerated() {
            EventEmitter.emit(PlaygroundEvent(
                type: "traverse",
                structure: "linkedList",
                index: index,
                value: value,
                highlight: [index],
                nodes: nodes,
                message: "\(name): Traverse → \(value)",
                meta: ["name": name],
                sourceLine: line
            ))
        }
    }
}
