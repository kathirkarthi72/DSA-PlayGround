import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class HashTableVisualizer: DSAVisualizer {
    public var buckets: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Hash table ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        buckets = []
        structures = [:]
        caption = "Hash table ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "Table"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "bucket-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            buckets = rebuilt
        }
    }

    public func makeView() -> some View {
        HashTableCanvas(visualizer: self)
    }
}

struct HashTableCanvas: View {
    @Bindable var visualizer: HashTableVisualizer
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    private func pointerFor(index: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else { return nil }
        let type = event.type.lowercased()
        
        if event.index == index {
            switch type {
            case "put":
                return ("PUT", PlaygroundTheme.accent)
            case "remove":
                return ("REMOVED", PlaygroundTheme.danger)
            case "get":
                return ("GET", PlaygroundTheme.accentSecondary)
            default:
                break
            }
        }
        
        if event.highlight.contains(index) {
            return ("PROBE", PlaygroundTheme.nodeHighlight)
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Hash Table")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleTableLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleTableLayout(visualizer.structures[name] ?? [])
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func singleTableLayout(_ nodes: [VizNode]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, bucket in
                VStack(alignment: .center, spacing: 4) {
                    HStack {
                        Text("bucket \(index)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(PlaygroundTheme.muted)
                        Spacer()
                        if let pointer = pointerFor(index: index) {
                            PointerOverlayView(label: pointer.label, color: pointer.color, direction: .left)
                        }
                    }
                    .frame(height: 18)
                    InteractiveNodeChip(node: bucket, width: 120, height: 44)
                }
            }
        }
        .padding()
    }
}

public struct HashTableModule: DSAModule {
    public let id = "hashTable"
    public let title = "Hash Table"
    public let systemImage = "tablecells"
    public let structureKey = "hashTable"
    public let bootstrapCode = "var table = AnimatedHashTable<String, Int>(capacity: 8)"

    public init() {}

    public var starterCode: String {
        """
        // Hash Table playground — put / get / remove (chaining)
        var table = AnimatedHashTable<String, Int>(capacity: 8)

        table.put("apple", 3)
        table.put("banana", 5)
        table.put("cherry", 7)
        _ = table.get("banana")
        table.put("date", 2)
        _ = table.remove("apple")
        _ = table.get("apple")
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "put", title: "Put", systemImage: "plus.square.on.square", snippet: "table.put(String(UnicodeScalar(Int.random(in: 97...122))!), Int.random(in: 1...9))"),
            .init(id: "get", title: "Get", systemImage: "magnifyingglass", snippet: "_ = table.get(\"a\")"),
            .init(id: "remove", title: "Remove", systemImage: "trash", snippet: "_ = table.remove(\"a\")"),
            .init(id: "putMultiple", title: "Put Multiple", systemImage: "plus.square.fill.on.square.fill", snippet: "table.put(\"x\", 1); table.put(\"y\", 2); table.put(\"z\", 3)"),
            .init(id: "clearAll", title: "Clear All", systemImage: "trash.slash", snippet: "_ = table.remove(\"x\"); _ = table.remove(\"y\"); _ = table.remove(\"z\")")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        HashTableVisualizer()
    }
}
