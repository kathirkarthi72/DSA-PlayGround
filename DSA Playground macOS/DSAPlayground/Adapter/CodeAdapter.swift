import Foundation
import DSACore

struct CodeAdaptation {
    let adaptedCode: String
    let detectedModuleID: String?
    let notes: [String]
    var didChange: Bool { !notes.isEmpty || adaptedCode != original }
    private let original: String

    init(original: String, adaptedCode: String, detectedModuleID: String?, notes: [String]) {
        self.original = original
        self.adaptedCode = adaptedCode
        self.detectedModuleID = detectedModuleID
        self.notes = notes
    }
}

enum CodeAdapter {
    static func adapt(_ source: String, preferredModuleID: String?) -> CodeAdaptation {
        var code = source
        var notes: [String] = []

        // Strip non-playground imports that break top-level compile.
        let blockedImports = ["UIKit", "SwiftUI", "AppKit", "Combine", "DSAKit"]
        let filteredLines = code.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for name in blockedImports where trimmed.hasPrefix("import \(name)") {
                notes.append("Removed `import \(name)` for playground compile.")
                return false
            }
            return true
        }
        code = filteredLines.joined(separator: "\n")

        let detected = detectModuleID(in: code) ?? preferredModuleID

        let replacements: [(pattern: String, template: String, note: String)] = [
            (#"\bStack\s*<"#, "AnimatedStack<", "Mapped Stack → AnimatedStack"),
            (#"\bQueue\s*<"#, "AnimatedQueue<", "Mapped Queue → AnimatedQueue"),
            (#"\bLinkedList\s*<"#, "AnimatedLinkedList<", "Mapped LinkedList → AnimatedLinkedList"),
            (#"\bBinarySearchTree\s*<"#, "AnimatedBinaryTree<", "Mapped BinarySearchTree → AnimatedBinaryTree"),
            (#"\bBST\s*<"#, "AnimatedBinaryTree<", "Mapped BST → AnimatedBinaryTree"),
            (#"\bBinaryTree\s*<"#, "AnimatedBinaryTree<", "Mapped BinaryTree → AnimatedBinaryTree"),
            (#"\bMinHeap\s*<"#, "AnimatedHeap<", "Mapped MinHeap → AnimatedHeap"),
            (#"\bMaxHeap\s*<"#, "AnimatedHeap<", "Mapped MaxHeap → AnimatedHeap"),
            (#"\bHeap\s*<"#, "AnimatedHeap<", "Mapped Heap → AnimatedHeap"),
            (#"\bHashMap\s*<"#, "AnimatedHashTable<", "Mapped HashMap → AnimatedHashTable"),
            (#"\bDictionary\s*<"#, "AnimatedHashTable<", "Mapped Dictionary → AnimatedHashTable"),
            (#"\bHashTable\s*<"#, "AnimatedHashTable<", "Mapped HashTable → AnimatedHashTable"),
            (#"\bArrayList\s*<"#, "AnimatedArray<", "Mapped ArrayList → AnimatedArray")
        ]

        for item in replacements {
            if let regex = try? NSRegularExpression(pattern: item.pattern) {
                let range = NSRange(code.startIndex..., in: code)
                let replaced = regex.stringByReplacingMatches(in: code, range: range, withTemplate: item.template)
                if replaced != code {
                    code = replaced
                    if !notes.contains(item.note) { notes.append(item.note) }
                }
            }
        }

        // Common method aliases → DSAKit
        let methodMaps: [(String, String, String)] = [
            (#"\.addFirst\("#, ".prepend(", "Mapped addFirst → prepend"),
            (#"\.addLast\("#, ".append(", "Mapped addLast → append"),
            (#"\.offer\("#, ".enqueue(", "Mapped offer → enqueue"),
            (#"\.poll\("#, ".dequeue(", "Mapped poll → dequeue"),
            (#"\.removeFirst\("#, ".dequeue(", "Mapped removeFirst → dequeue"),
            (#"\.putValue\("#, ".put(", "Mapped putValue → put"),
            (#"\.extractMin\("#, ".extract(", "Mapped extractMin → extract"),
            (#"\.extractMax\("#, ".extract(", "Mapped extractMax → extract"),
            (#"\.inorder\("#, ".traverseInorder(", "Mapped inorder → traverseInorder")
        ]
        for (pattern, template, note) in methodMaps {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(code.startIndex..., in: code)
                let replaced = regex.stringByReplacingMatches(in: code, range: range, withTemplate: template)
                if replaced != code {
                    code = replaced
                    if !notes.contains(note) { notes.append(note) }
                }
            }
        }

        // Ensure a bootstrap exists when operations are present but no Animated* type is constructed.
        if let detected,
           !code.contains("Animated"),
           looksLikeOperations(code, moduleID: detected) {
            let bootstrap = bootstrap(for: detected)
            code = bootstrap + "\n\n" + code
            notes.append("Injected \(detected) bootstrap for pasted operations.")
        }

        // Wrap `func solution...` style LeetCode pastes: keep helpers and call a demo.
        if code.contains("func "), !code.contains("Animated"), let detected {
            let bootstrap = bootstrap(for: detected)
            let demo = demoCall(for: detected)
            code = """
            \(bootstrap)

            // Adapted from pasted problem code
            \(code)

            // Demo drive for visualization
            \(demo)
            """
            notes.append("Wrapped pasted functions with an animated \(detected) demo.")
        }

        if !code.hasSuffix("\n") { code += "\n" }
        return CodeAdaptation(
            original: source,
            adaptedCode: code,
            detectedModuleID: detected,
            notes: notes
        )
    }

    static func detectModuleID(in source: String) -> String? {
        let lower = source.lowercased()
        let scores: [(String, [String])] = [
            ("stack", ["stack", "push(", "pop(", "peek("]),
            ("queue", ["queue", "enqueue(", "dequeue(", "offer(", "poll("]),
            ("linkedlist", ["linkedlist", "linked list", "prepend(", "addfirst("]),
            ("hashtable", ["hashtable", "hash map", "hashmap", "dictionary", ".put(", "collision"]),
            ("heap", ["heap", "extractmin", "extractmax", "heapify"]),
            ("tree", ["binarytree", "bst", "binary search tree", "inorder", "traverseinorder"]),
            ("array", ["animatedarray", "arraylist", "insert(at:", "remove(at:"])
        ]

        var best: (String, Int)?
        for (id, keys) in scores {
            let score = keys.reduce(0) { partial, key in
                partial + (lower.contains(key) ? 1 : 0)
            }
            if score > 0, best == nil || score > best!.1 {
                best = (normalizedID(id), score)
            }
        }
        return best?.0
    }

    private static func normalizedID(_ raw: String) -> String {
        switch raw {
        case "linkedlist": return "linkedList"
        case "hashtable": return "hashTable"
        default: return raw
        }
    }

    private static func looksLikeOperations(_ code: String, moduleID: String) -> Bool {
        switch moduleID {
        case "stack": return code.contains("push(") || code.contains("pop(")
        case "queue": return code.contains("enqueue(") || code.contains("dequeue(") || code.contains("offer(")
        case "array": return code.contains("append(") || code.contains("insert(")
        case "linkedList": return code.contains("append(") || code.contains("prepend(")
        case "hashTable": return code.contains("put(") || code.contains("get(")
        case "heap": return code.contains("insert(") || code.contains("extract(")
        case "tree": return code.contains("insert(") || code.contains("search(")
        default: return false
        }
    }

    private static func bootstrap(for moduleID: String) -> String {
        switch moduleID {
        case "stack": return "var stack = AnimatedStack<Int>()"
        case "queue": return "var queue = AnimatedQueue<Int>()"
        case "array": return "var array = AnimatedArray<Int>()"
        case "linkedList": return "let list = AnimatedLinkedList<Int>()"
        case "hashTable": return "var table = AnimatedHashTable<String, Int>(capacity: 8)"
        case "heap": return "var heap = AnimatedHeap<Int>(kind: .min)"
        case "tree": return "let tree = AnimatedBinaryTree<Int>()"
        default: return ""
        }
    }

    private static func demoCall(for moduleID: String) -> String {
        switch moduleID {
        case "stack":
            return """
            stack.push(10)
            stack.push(20)
            _ = stack.pop()
            """
        case "queue":
            return """
            queue.enqueue(1)
            queue.enqueue(2)
            _ = queue.dequeue()
            """
        case "array":
            return """
            array.append(1)
            array.append(2)
            array.insert(3, at: 1)
            """
        case "linkedList":
            return """
            list.append(1)
            list.append(2)
            list.traverse()
            """
        case "hashTable":
            return """
            table.put("x", 1)
            table.put("y", 2)
            _ = table.get("x")
            """
        case "heap":
            return """
            heap.insert(5)
            heap.insert(1)
            _ = heap.extract()
            """
        case "tree":
            return """
            tree.insert(8)
            tree.insert(3)
            tree.insert(10)
            tree.traverseInorder()
            """
        default:
            return ""
        }
    }
}
