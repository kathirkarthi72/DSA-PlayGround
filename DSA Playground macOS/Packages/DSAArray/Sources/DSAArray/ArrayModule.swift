import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class ArrayVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Array ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Array ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "Array"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "array-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            nodes = rebuilt
        }
    }

    public func makeView() -> some View {
        ArrayVisualizerView(visualizer: self)
    }
}

struct ArrayVisualizerView: View {
    @Bindable var visualizer: ArrayVisualizer

    private func pointerFor(index: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else { return nil }
        let type = event.type.lowercased()
        
        if event.index == index {
            switch type {
            case "insert", "append":
                return ("INSERTED", PlaygroundTheme.accent)
            case "remove", "pop", "dequeue":
                return ("REMOVED", PlaygroundTheme.danger)
            case "set", "put":
                return ("SET", PlaygroundTheme.accentSecondary)
            case "get", "peek", "access":
                return ("READ", PlaygroundTheme.accent)
            default:
                break
            }
        }
        
        if event.highlight.contains(index) {
            switch type {
            case "swap":
                return ("SWAP", PlaygroundTheme.accentSecondary)
            case "compare":
                return ("COMPARE", PlaygroundTheme.accent)
            case "highlight", "visit":
                return ("VISIT", PlaygroundTheme.nodeHighlight)
            default:
                return ("ACTIVE", PlaygroundTheme.nodeHighlight)
            }
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption, event: visualizer.lastEvent, nodes: visualizer.nodes) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Array")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleArrayLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleArrayLayout(visualizer.structures[name] ?? [])
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func singleArrayLayout(_ nodes: [VizNode]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    VStack(spacing: 6) {
                        if let pointer = pointerFor(index: index) {
                            PointerOverlayView(label: pointer.label, color: pointer.color, direction: .down)
                                .frame(height: 24)
                        } else {
                            Spacer()
                                .frame(height: 24)
                        }
                        InteractiveNodeChip(node: node)
                        Text("[\(index)]")
                            .font(.caption2.monospaced())
                            .foregroundStyle(PlaygroundTheme.muted)
                    }
                    .transition(.playgroundInsert)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .animation(PlaygroundTheme.springBouncy, value: nodes)
        }
    }
}

public struct ArrayModule: DSAModule {
    public let id = "array"
    public let title = "Array"
    public let systemImage = "square.grid.3x1.below.line.grid.1x2"
    public let structureKey = "array"
    public let bootstrapCode = "var array = AnimatedArray<Int>()"

    public init() {}

    public var starterCode: String {
        """
        // Array playground — append / insert / remove / access
        var array = AnimatedArray<Int>()

        array.append(5)
        array.append(10)
        array.append(15)
        array.insert(7, at: 1)
        _ = array.at(2)
        _ = array.remove(at: 0)
        array.append(20)
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "append", title: "Append", systemImage: "plus", snippet: "array.append(Int.random(in: 1...50))"),
            .init(id: "prepend", title: "Prepend", systemImage: "text.insert", snippet: "array.insert(Int.random(in: 1...50), at: 0)"),
            .init(id: "insertIndex2", title: "Insert at Index 2", systemImage: "arrow.right.to.line.compact", snippet: "array.insert(Int.random(in: 1...50), at: 2)"),
            .init(id: "access", title: "Access Index 0", systemImage: "hand.tap", snippet: "_ = array.at(0)"),
            .init(id: "removeIndex0", title: "Remove Index 0", systemImage: "trash", snippet: "_ = array.remove(at: 0)"),
            .init(id: "removeLast", title: "Remove Last", systemImage: "trash.slash", snippet: "_ = array.remove(at: array.count - 1)"),
            .init(id: "errorCheck", title: "Out-of-Bounds Check", systemImage: "exclamationmark.triangle", snippet: "_ = array.at(99)"),
            .init(id: "clearAll", title: "Clear All", systemImage: "clear", snippet: "while !array.isEmpty { _ = array.remove(at: 0) }")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        ArrayVisualizer()
    }
}
