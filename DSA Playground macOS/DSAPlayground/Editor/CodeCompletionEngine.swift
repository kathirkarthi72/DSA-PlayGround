import Foundation

struct CodeSuggestion: Identifiable, Equatable, Hashable {
    enum Kind: String {
        case symbol
        case snippet
        case prediction
        case appleIntelligence
    }

    var id: String { "\(kind.rawValue)|\(displayText)|\(insertText)|\(replacePrefixLength)" }
    let insertText: String
    let displayText: String
    let detail: String
    /// Longer explanation shown in the completion list.
    let description: String
    let kind: Kind

    /// Characters before the caret to replace (for symbol completion).
    let replacePrefixLength: Int

    init(
        insertText: String,
        displayText: String,
        detail: String,
        description: String = "",
        kind: Kind,
        replacePrefixLength: Int
    ) {
        self.insertText = insertText
        self.displayText = displayText
        self.detail = detail
        self.description = description.isEmpty ? detail : description
        self.kind = kind
        self.replacePrefixLength = replacePrefixLength
    }
}

final class CodeCompletionEngine: @unchecked Sendable {
    var useAppleIntelligence: Bool = true

    private let localSymbols: [(symbol: String, insert: String, description: String)] = [
        ("AnimatedStack", "AnimatedStack<Int>()", "LIFO stack that emits visualization events on push/pop/peek."),
        ("AnimatedQueue", "AnimatedQueue<Int>()", "FIFO queue that animates enqueue/dequeue/peek."),
        ("AnimatedArray", "AnimatedArray<Int>()", "Dynamic array with animated append/insert/remove/access."),
        ("AnimatedLinkedList", "AnimatedLinkedList<Int>()", "Singly linked list with animated pointer updates."),
        ("AnimatedHashTable", "AnimatedHashTable<String, Int>(capacity: 8)", "Hash map with animated put/get/remove bucket updates."),
        ("AnimatedHeap", "AnimatedHeap<Int>(kind: .min)", "Binary heap with animated insert/extract heapify steps."),
        ("AnimatedBinaryTree", "AnimatedBinaryTree<Int>()", "BST with animated insert/search/delete/traverse."),
        ("push", "push(", "Push a value onto the top of a stack."),
        ("pop", "pop()", "Remove and return the top stack value."),
        ("peek", "peek()", "Read the front/top value without removing it."),
        ("enqueue", "enqueue(", "Add a value to the back of a queue."),
        ("dequeue", "dequeue()", "Remove and return the front queue value."),
        ("append", "append(", "Add a value at the end of an array or list."),
        ("prepend", "prepend(", "Insert a value at the head of a linked list."),
        ("insert", "insert(", "Insert a value at an index or into a tree/heap."),
        ("remove", "remove(at: ", "Remove a value at the given index."),
        ("traverse", "traverse()", "Walk list nodes in order and highlight them."),
        ("traverseInorder", "traverseInorder()", "BST inorder traversal (sorted order)."),
        ("extract", "extract()", "Remove and return the heap root (min or max)."),
        ("search", "search(", "Search for a value in a tree or structure."),
        ("delete", "delete(", "Delete a value from a binary search tree."),
        ("put", "put(", "Insert or update a key/value in a hash table."),
        ("get", "get(", "Look up a value by key in a hash table."),
        ("at", "at(", "Access an array element by index."),
        ("var", "var ", "Declare a mutable variable."),
        ("let", "let ", "Declare an immutable constant."),
        ("func", "func ", "Declare a function."),
        ("if", "if ", "Conditional branch."),
        ("else", "else ", "Alternate branch for an if."),
        ("for", "for ", "Loop over a sequence."),
        ("while", "while ", "Loop while a condition is true."),
        ("return", "return ", "Return a value from a function."),
        ("true", "true", "Boolean true literal."),
        ("false", "false", "Boolean false literal."),
        ("nil", "nil", "Optional absence of a value.")
    ]

    private let nextLineHeuristics: [(triggerSuffix: String, prediction: String, description: String)] = [
        ("AnimatedStack<Int>()", "\nstack.push(10)", "Push the first value onto the new stack."),
        ("AnimatedQueue<Int>()", "\nqueue.enqueue(1)", "Enqueue the first value into the new queue."),
        ("AnimatedQueue<String>()", "\nqueue.enqueue(\"A\")", "Enqueue the first string into the new queue."),
        ("AnimatedArray<Int>()", "\narray.append(1)", "Append the first value to the array."),
        ("AnimatedLinkedList<Int>()", "\nlist.append(1)", "Append the first node to the linked list."),
        ("AnimatedHeap<Int>(kind: .min)", "\nheap.insert(10)", "Insert the first value into the heap."),
        ("AnimatedBinaryTree<Int>()", "\ntree.insert(50)", "Insert the root value into the BST."),
        ("AnimatedHashTable<String, Int>(capacity: 8)", "\ntable.put(\"a\", 1)", "Store the first key/value pair."),
        ("push(", ")", "Close the push(…) call."),
        ("enqueue(", ")", "Close the enqueue(…) call."),
        ("append(", ")", "Close the append(…) call."),
        ("insert(", ")", "Close the insert(…) call."),
        ("put(", ")", "Close the put(…) call."),
        ("search(", ")", "Close the search(…) call."),
        ("delete(", ")", "Close the delete(…) call.")
    ]

    func localSuggestions(source: String, cursor: Int) -> [CodeSuggestion] {
        let prefix = currentTokenPrefix(in: source, cursor: cursor)
        guard !prefix.isEmpty else { return [] }

        var results: [CodeSuggestion] = []
        let lower = prefix.lowercased()

        for item in localSymbols where item.symbol.lowercased().hasPrefix(lower) && item.symbol.lowercased() != lower {
            let insert = item.insert
            let insertText: String
            let replaceLen: Int
            if insert.lowercased().hasPrefix(lower) {
                insertText = String(insert.dropFirst(prefix.count))
                replaceLen = 0
            } else {
                insertText = insert
                replaceLen = prefix.count
            }

            results.append(CodeSuggestion(
                insertText: insertText,
                displayText: item.symbol,
                detail: insert,
                description: item.description,
                kind: .symbol,
                replacePrefixLength: replaceLen
            ))
        }

        // Identifiers already present in the file.
        let identifiers = Set(source.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.map(String.init))
            .filter { $0.count > 2 && $0.lowercased().hasPrefix(lower) && $0.lowercased() != lower }
        for name in identifiers.sorted().prefix(8) {
            if results.contains(where: { $0.displayText == name }) { continue }
            results.append(CodeSuggestion(
                insertText: String(name.dropFirst(prefix.count)),
                displayText: name,
                detail: "in file",
                description: "Identifier already used in this file.",
                kind: .symbol,
                replacePrefixLength: 0
            ))
        }

        return Array(results.prefix(10))
    }

    func localInlinePrediction(source: String, cursor: Int) -> CodeSuggestion? {
        let before = String(source.prefix(cursor))
        let trimmedLine = before.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let lineTrim = trimmedLine.trimmingCharacters(in: .whitespaces)

        for item in nextLineHeuristics {
            if lineTrim.hasSuffix(item.triggerSuffix) || before.hasSuffix(item.triggerSuffix) {
                return CodeSuggestion(
                    insertText: item.prediction,
                    displayText: item.prediction.replacingOccurrences(of: "\n", with: "↵ "),
                    detail: "Next line",
                    description: item.description,
                    kind: .prediction,
                    replacePrefixLength: 0
                )
            }
        }

        if let open = trimmedLine.last, "({[\"".contains(open) {
            let close: String
            switch open {
            case "(": close = ")"
            case "{": close = "}"
            case "[": close = "]"
            case "\"": close = "\""
            default: close = ""
            }
            if !close.isEmpty {
                return CodeSuggestion(
                    insertText: close,
                    displayText: close,
                    detail: "Close pair",
                    description: "Insert the matching closing delimiter.",
                    kind: .snippet,
                    replacePrefixLength: 0
                )
            }
        }

        if lineTrim.hasSuffix(")") || lineTrim.hasSuffix("()") {
            if before.contains("AnimatedStack") {
                return CodeSuggestion(
                    insertText: "\nstack.push(20)",
                    displayText: "stack.push(20)",
                    detail: "Suggested next",
                    description: "Continue the stack demo with another push.",
                    kind: .prediction,
                    replacePrefixLength: 0
                )
            }
            if before.contains("AnimatedQueue") {
                return CodeSuggestion(
                    insertText: "\nqueue.enqueue(2)",
                    displayText: "queue.enqueue(2)",
                    detail: "Suggested next",
                    description: "Continue the queue demo with another enqueue.",
                    kind: .prediction,
                    replacePrefixLength: 0
                )
            }
        }

        if let first = localSuggestions(source: source, cursor: cursor).first, !first.insertText.isEmpty {
            return CodeSuggestion(
                insertText: first.insertText,
                displayText: first.displayText,
                detail: "Autocomplete",
                description: first.description,
                kind: .symbol,
                replacePrefixLength: first.replacePrefixLength
            )
        }
        return nil
    }

    func currentTokenPrefix(in source: String, cursor: Int) -> String {
        guard cursor > 0, cursor <= source.count else { return "" }
        let idx = source.index(source.startIndex, offsetBy: cursor)
        var start = idx
        while start > source.startIndex {
            let prev = source.index(before: start)
            if source[prev].isLetter || source[prev].isNumber || source[prev] == "_" {
                start = prev
            } else {
                break
            }
        }
        return String(source[start..<idx])
    }
}
