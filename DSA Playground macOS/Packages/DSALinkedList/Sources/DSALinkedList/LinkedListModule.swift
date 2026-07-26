import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class LinkedListVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Linked list ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Linked list ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "List"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "ll-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            nodes = rebuilt
        }
    }

    public func makeView() -> some View {
        LinkedListCanvas(visualizer: self)
    }
}

struct LinkedListCanvas: View {
    @Bindable var visualizer: LinkedListVisualizer

    private func pointerFor(index: Int, count: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else {
            if index == 0 {
                return ("HEAD", PlaygroundTheme.accent)
            } else if index == count - 1 {
                return ("TAIL", PlaygroundTheme.accentSecondary)
            }
            return nil
        }
        let type = event.type.lowercased()
        
        if event.index == index {
            switch type {
            case "prepend":
                return ("NEW HEAD", PlaygroundTheme.accent)
            case "append":
                return ("NEW TAIL", PlaygroundTheme.accentSecondary)
            case "insert":
                return ("INSERT", PlaygroundTheme.accent)
            case "remove", "pop", "dequeue":
                return ("REMOVED", PlaygroundTheme.danger)
            default:
                break
            }
        }
        
        if event.highlight.contains(index) {
            switch type {
            case "traverse", "visit":
                return ("CURRENT", PlaygroundTheme.nodeHighlight)
            case "compare":
                return ("COMPARE", PlaygroundTheme.accent)
            default:
                return ("ACTIVE", PlaygroundTheme.nodeHighlight)
            }
        }
        
        if index == 0 {
            return ("HEAD", PlaygroundTheme.accent)
        } else if index == count - 1 {
            return ("TAIL", PlaygroundTheme.accentSecondary)
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Linked List")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleListLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleListLayout(visualizer.structures[name] ?? [])
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func singleListLayout(_ nodes: [VizNode]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            if let pointer = pointerFor(index: index, count: nodes.count) {
                                PointerOverlayView(label: pointer.label, color: pointer.color, direction: .down)
                                    .frame(height: 24)
                            } else {
                                Spacer()
                                    .frame(height: 24)
                            }
                            InteractiveNodeChip(node: node, width: 64)
                        }
                        if index < nodes.count - 1 {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(PlaygroundTheme.accent)
                                .symbolEffect(.bounce, value: visualizer.caption)
                                .padding(.horizontal, 8)
                                .offset(y: 15)
                        } else {
                            Text(" → nil")
                                .font(.caption.monospaced())
                                .foregroundStyle(PlaygroundTheme.muted)
                                .padding(.leading, 8)
                                .offset(y: 15)
                        }
                    }
                    .transition(.playgroundSlide)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

public struct LinkedListModule: DSAModule {
    public let id = "linkedList"
    public let title = "Linked List"
    public let systemImage = "link"
    public let structureKey = "linkedList"
    public let bootstrapCode = "let list = AnimatedLinkedList<Int>()"

    public init() {}

    public var starterCode: String {
        """
        // Linked List playground — append / prepend / insert / remove / traverse
        let list = AnimatedLinkedList<Int>()

        list.append(10)
        list.append(20)
        list.prepend(5)
        list.insert(15, at: 2)
        list.traverse()
        _ = list.remove(at: 1)
        list.traverse()
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "append", title: "Append", systemImage: "plus", snippet: "list.append(Int.random(in: 1...40))"),
            .init(id: "prepend", title: "Prepend", systemImage: "text.insert", snippet: "list.prepend(Int.random(in: 1...40))"),
            .init(id: "insertIndex2", title: "Insert at Index 2", systemImage: "arrow.right.to.line.compact", snippet: "list.insert(Int.random(in: 1...40), at: 2)"),
            .init(id: "traverse", title: "Traverse", systemImage: "arrow.right.circle", snippet: "list.traverse()"),
            .init(id: "removeHead", title: "Remove Head", systemImage: "trash", snippet: "_ = list.remove(at: 0)"),
            .init(id: "removeTail", title: "Remove Tail", systemImage: "trash.slash", snippet: "_ = list.remove(at: list.count - 1)")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        LinkedListVisualizer()
    }
}
