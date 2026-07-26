import Foundation

public final class AnimatedBinaryTree<Element: Comparable> {
    private final class Node {
        var value: Element
        var left: Node?
        var right: Node?
        init(_ value: Element) { self.value = value }
    }

    private var root: Node?
    private let name: String

    public init(name: String? = nil, line: Int = #line) {
        let actualName = name ?? "Tree \(InstanceCounter.shared.nextIndex(for: "tree"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "tree",
            nodes: [],
            message: "\(actualName) ready",
            meta: ["name": actualName],
            sourceLine: line
        ))
    }

    private func inorder(_ node: Node?, into values: inout [String]) {
        guard let node else { return }
        inorder(node.left, into: &values)
        values.append(EventEmitter.valueString(node.value))
        inorder(node.right, into: &values)
    }

    private func snapshot() -> [String] {
        var values: [String] = []
        inorder(root, into: &values)
        return values
    }

    private func levelOrderValues() -> [String] {
        guard let root else { return [] }
        var result: [String] = []
        var queue: [Node?] = [root]
        var remaining = 1
        while remaining > 0, !queue.isEmpty {
            let node = queue.removeFirst()
            if let node {
                remaining -= 1
                result.append(EventEmitter.valueString(node.value))
                queue.append(node.left)
                queue.append(node.right)
                if node.left != nil { remaining += 1 }
                if node.right != nil { remaining += 1 }
            } else {
                result.append("·")
                queue.append(nil)
                queue.append(nil)
            }
            if result.count > 31 { break }
        }
        while result.last == "·" { result.removeLast() }
        return result
    }

    public func insert(_ value: Element, line: Int = #line) {
        root = insert(value, into: root, path: [], line: line)
        EventEmitter.emit(PlaygroundEvent(
            type: "insert",
            structure: "tree",
            value: EventEmitter.valueString(value),
            highlight: [],
            nodes: levelOrderValues(),
            message: "\(name): Insert \(EventEmitter.valueString(value))",
            meta: ["inorder": snapshot().joined(separator: ","), "name": name],
            sourceLine: line
        ))
    }

    private func insert(_ value: Element, into node: Node?, path: [String], line: Int) -> Node {
        guard let node else {
            EventEmitter.emit(PlaygroundEvent(
                type: "visit",
                structure: "tree",
                value: EventEmitter.valueString(value),
                nodes: levelOrderValues(),
                message: "\(name): Place \(EventEmitter.valueString(value))",
                meta: ["path": path.joined(separator: "/"), "name": name],
                sourceLine: line
            ))
            return Node(value)
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "visit",
            structure: "tree",
            value: EventEmitter.valueString(node.value),
            nodes: levelOrderValues(),
            message: "\(name): Visit \(EventEmitter.valueString(node.value))",
            meta: ["path": path.joined(separator: "/"), "name": name],
            sourceLine: line
        ))
        if value < node.value {
            node.left = insert(value, into: node.left, path: path + ["L"], line: line)
        } else if value > node.value {
            node.right = insert(value, into: node.right, path: path + ["R"], line: line)
        }
        return node
    }

    @discardableResult
    public func search(_ value: Element, line: Int = #line) -> Bool {
        var current = root
        while let node = current {
            EventEmitter.emit(PlaygroundEvent(
                type: "search",
                structure: "tree",
                value: EventEmitter.valueString(value),
                secondaryValue: EventEmitter.valueString(node.value),
                nodes: levelOrderValues(),
                message: "\(name): Compare \(EventEmitter.valueString(value)) with \(EventEmitter.valueString(node.value))",
                meta: ["name": name],
                sourceLine: line
            ))
            if value == node.value {
                EventEmitter.emit(PlaygroundEvent(
                    type: "found",
                    structure: "tree",
                    value: EventEmitter.valueString(value),
                    nodes: levelOrderValues(),
                    message: "\(name): Found \(EventEmitter.valueString(value))",
                    meta: ["name": name],
                    sourceLine: line
                ))
                return true
            }
            current = value < node.value ? node.left : node.right
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "miss",
            structure: "tree",
            value: EventEmitter.valueString(value),
            nodes: levelOrderValues(),
            message: "\(name): Not found \(EventEmitter.valueString(value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return false
    }

    public func traverseInorder(line: Int = #line) {
        var values: [String] = []
        func walk(_ node: Node?) {
            guard let node else { return }
            walk(node.left)
            values.append(EventEmitter.valueString(node.value))
            EventEmitter.emit(PlaygroundEvent(
                type: "traverse",
                structure: "tree",
                value: EventEmitter.valueString(node.value),
                nodes: levelOrderValues(),
                message: "\(name): Inorder → \(EventEmitter.valueString(node.value))",
                meta: ["visited": values.joined(separator: ","), "name": name],
                sourceLine: line
            ))
            walk(node.right)
        }
        walk(root)
    }

    public func delete(_ value: Element, line: Int = #line) {
        root = delete(value, from: root, line: line)
        EventEmitter.emit(PlaygroundEvent(
            type: "delete",
            structure: "tree",
            value: EventEmitter.valueString(value),
            nodes: levelOrderValues(),
            message: "\(name): Delete \(EventEmitter.valueString(value))",
            meta: ["inorder": snapshot().joined(separator: ","), "name": name],
            sourceLine: line
        ))
    }

    private func delete(_ value: Element, from node: Node?, line: Int) -> Node? {
        guard let node else { return nil }
        EventEmitter.emit(PlaygroundEvent(
            type: "visit",
            structure: "tree",
            value: EventEmitter.valueString(node.value),
            nodes: levelOrderValues(),
            message: "\(name): Visit \(EventEmitter.valueString(node.value)) for delete",
            meta: ["name": name],
            sourceLine: line
        ))
        if value < node.value {
            node.left = delete(value, from: node.left, line: line)
            return node
        }
        if value > node.value {
            node.right = delete(value, from: node.right, line: line)
            return node
        }
        if node.left == nil { return node.right }
        if node.right == nil { return node.left }
        var successor = node.right
        while let left = successor?.left {
            successor = left
        }
        if let successor {
            node.value = successor.value
            node.right = delete(successor.value, from: node.right, line: line)
        }
        return node
    }
}
