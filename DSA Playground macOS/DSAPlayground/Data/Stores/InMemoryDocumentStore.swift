import Foundation

/// In-memory per-DSA document store (Data layer).
final class InMemoryDocumentStore: DocumentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var workspaces: [String: ModuleWorkspace] = [:]

    func workspace(for moduleID: String) -> ModuleWorkspace? {
        lock.lock()
        defer { lock.unlock() }
        return workspaces[moduleID]
    }

    func ensureWorkspace(for moduleID: String, starterCode: String) -> ModuleWorkspace {
        lock.lock()
        defer { lock.unlock() }
        
        var workspace: ModuleWorkspace
        if let existing = workspaces[moduleID] {
            workspace = existing
        } else {
            let main = EditorDocument(name: "main.swift", content: starterCode, isEntrypoint: true)
            workspace = ModuleWorkspace(id: moduleID, documents: [main])
        }
        
        var docs = workspace.documents
        
        // Find existing core docs or create new ones
        let main: EditorDocument
        if let existing = docs.first(where: { $0.name == "main.swift" }) {
            main = existing
        } else {
            main = EditorDocument(name: "main.swift", content: starterCode, isEntrypoint: true)
        }
        
        let helpers: EditorDocument
        if let existing = docs.first(where: { $0.name.lowercased() == "helpers.swift" }) {
            var updated = existing
            updated.name = "helpers.swift"
            helpers = updated
        } else if let existingOld = docs.first(where: { $0.name == "Helpers.swift" }) {
            var updated = existingOld
            updated.name = "helpers.swift"
            helpers = updated
        } else {
            helpers = EditorDocument(
                name: "helpers.swift",
                content: """
                // Shared helpers for this DSA playground (compiled with main.swift)
                // Example:
                // func demoValues() -> [Int] { [1, 2, 3] }

                """,
                isEntrypoint: false
            )
        }
        
        let tests: EditorDocument
        if let existing = docs.first(where: { $0.name == "tests.swift" }) {
            tests = existing
        } else {
            tests = EditorDocument(
                name: "tests.swift",
                content: generateTestsCode(for: moduleID),
                isEntrypoint: false
            )
        }
        
        let inbuild: EditorDocument
        if var existing = docs.first(where: { $0.name == "inbuild.swift" }) {
            existing.isReadOnly = true
            if existing.content.isEmpty || existing.content.hasPrefix("// Inbuild code for") {
                existing.content = loadInbuildCode(for: moduleID)
            }
            inbuild = existing
        } else {
            inbuild = EditorDocument(
                name: "inbuild.swift",
                content: loadInbuildCode(for: moduleID),
                isEntrypoint: false,
                isReadOnly: true
            )
        }
        
        // Find any other custom documents (e.g. interview questions)
        let coreNames = ["main.swift", "helpers.swift", "Helpers.swift", "tests.swift", "inbuild.swift"]
        let customDocs = docs.filter { !coreNames.contains($0.name) }
        
        // Assemble in the required order: [inbuild, main, helpers, tests] + customDocs
        let orderedDocs = [inbuild, main, helpers, tests] + customDocs
        workspace.documents = orderedDocs
        
        if !orderedDocs.contains(where: { $0.id == workspace.activeDocumentID }) {
            // Default to main.swift on initial creation/migration
            workspace.activeDocumentID = main.id
        }
        
        workspaces[moduleID] = workspace
        return workspace
    }

    func save(_ workspace: ModuleWorkspace) {
        lock.lock()
        defer { lock.unlock() }
        workspaces[workspace.id] = workspace
    }

    func allModuleIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(workspaces.keys)
    }

    private func loadInbuildCode(for moduleID: String) -> String {
        let filename: String
        switch moduleID {
        case "array": filename = "AnimatedArray.swift"
        case "linkedList": filename = "AnimatedLinkedList.swift"
        case "stack": filename = "AnimatedStack.swift"
        case "queue": filename = "AnimatedQueue.swift"
        case "hashTable": filename = "AnimatedHashTable.swift"
        case "heap": filename = "AnimatedHeap.swift"
        case "tree": filename = "AnimatedBinaryTree.swift"
        default: return "// No inbuild code available for \(moduleID)\n"
        }

        let fm = FileManager.default
        var urls: [URL] = []

        if let resourceRoot = Bundle.main.resourceURL {
            urls.append(resourceRoot.appendingPathComponent("DSAKitSources").appendingPathComponent(filename))
            urls.append(resourceRoot.appendingPathComponent(filename))
        }

        let relativeCandidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/DSAKitSources")
                .appendingPathComponent(filename),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Packages/DSAKit/Sources/DSAKit")
                .appendingPathComponent(filename)
        ]
        urls.append(contentsOf: relativeCandidates)

        for url in urls {
            if fm.fileExists(atPath: url.path) {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    return content
                }
            }
        }

        return "// Inbuild code for \(filename) could not be loaded.\n"
    }

    private func generateTestsCode(for moduleID: String) -> String {
        switch moduleID {
        case "array":
            return """
            import XCTest

            class ArrayTests: XCTestCase {
                func testAppend() {
                    var array = AnimatedArray<Int>()
                    array.append(10)
                    XCTAssertEqual(array.count, 1)
                }

                func testInsert() {
                    var array = AnimatedArray<Int>()
                    array.append(10)
                    array.append(20)
                    array.insert(15, at: 1)
                    XCTAssertEqual(array.count, 3)
                }

                func testRemove() {
                    var array = AnimatedArray<Int>()
                    array.append(10)
                    let val = array.remove(at: 0)
                    XCTAssertEqual(val, 10)
                    XCTAssertEqual(array.count, 0)
                }
            }

            // Run the tests
            let suite = ArrayTests.defaultTestSuite
            suite.run()
            """
        case "linkedList":
            return """
            import XCTest

            class LinkedListTests: XCTestCase {
                func testAppend() {
                    let list = AnimatedLinkedList<Int>()
                    list.append(10)
                    XCTAssertEqual(list.count, 1)
                }

                func testPrepend() {
                    let list = AnimatedLinkedList<Int>()
                    list.prepend(20)
                    XCTAssertEqual(list.count, 1)
                }

                func testRemove() {
                    let list = AnimatedLinkedList<Int>()
                    list.append(10)
                    let val = list.remove(at: 0)
                    XCTAssertEqual(val, 10)
                    XCTAssertEqual(list.count, 0)
                }
            }

            // Run the tests
            let suite = LinkedListTests.defaultTestSuite
            suite.run()
            """
        case "stack":
            return """
            import XCTest

            class StackTests: XCTestCase {
                func testPush() {
                    var stack = AnimatedStack<Int>()
                    stack.push(10)
                    XCTAssertEqual(stack.count, 1)
                }

                func testPop() {
                    var stack = AnimatedStack<Int>()
                    stack.push(10)
                    stack.push(20)
                    let popped = stack.pop()
                    XCTAssertEqual(popped, 20)
                    XCTAssertEqual(stack.count, 1)
                }

                func testPeek() {
                    let stack = AnimatedStack<Int>()
                    XCTAssertNil(stack.peek())
                }
            }

            // Run the tests
            let suite = StackTests.defaultTestSuite
            suite.run()
            """
        case "queue":
            return """
            import XCTest

            class QueueTests: XCTestCase {
                func testEnqueue() {
                    var queue = AnimatedQueue<Int>()
                    queue.enqueue(10)
                    XCTAssertEqual(queue.count, 1)
                }

                func testDequeue() {
                    var queue = AnimatedQueue<Int>()
                    queue.enqueue(10)
                    queue.enqueue(20)
                    let val = queue.dequeue()
                    XCTAssertEqual(val, 10)
                    XCTAssertEqual(queue.count, 1)
                }
            }

            // Run the tests
            let suite = QueueTests.defaultTestSuite
            suite.run()
            """
        case "hashTable":
            return """
            import XCTest

            class HashTableTests: XCTestCase {
                func testPutAndGet() {
                    var table = AnimatedHashTable<String, Int>()
                    table.put("test", 100)
                    XCTAssertEqual(table.get("test"), 100)
                }

                func testRemove() {
                    var table = AnimatedHashTable<String, Int>()
                    table.put("test", 100)
                    table.remove("test")
                    XCTAssertNil(table.get("test"))
                }
            }

            // Run the tests
            let suite = HashTableTests.defaultTestSuite
            suite.run()
            """
        case "heap":
            return """
            import XCTest

            class HeapTests: XCTestCase {
                func testInsert() {
                    var heap = AnimatedHeap<Int>()
                    heap.insert(10)
                    XCTAssertEqual(heap.count, 1)
                }

                func testExtract() {
                    var heap = AnimatedHeap<Int>()
                    heap.insert(20)
                    heap.insert(10)
                    heap.insert(30)
                    let val = heap.extract()
                    XCTAssertEqual(val, 10)
                }
            }

            // Run the tests
            let suite = HeapTests.defaultTestSuite
            suite.run()
            """
        case "tree":
            return """
            import XCTest

            class TreeTests: XCTestCase {
                func testInsert() {
                    let tree = AnimatedBinaryTree<Int>()
                    tree.insert(10)
                    XCTAssertTrue(tree.search(10))
                }

                func testDelete() {
                    let tree = AnimatedBinaryTree<Int>()
                    tree.insert(10)
                    tree.insert(5)
                    tree.delete(5)
                    XCTAssertFalse(tree.search(5))
                }
            }

            // Run the tests
            let suite = TreeTests.defaultTestSuite
            suite.run()
            """
        default:
            return """
            import XCTest

            class DSATests: XCTestCase {
                func testExample() {
                    XCTAssertTrue(true)
                }
            }

            // Run the tests
            let suite = DSATests.defaultTestSuite
            suite.run()
            """
        }
    }
}
