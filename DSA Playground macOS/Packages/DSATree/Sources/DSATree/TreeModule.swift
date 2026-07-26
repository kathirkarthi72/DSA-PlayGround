import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class TreeVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Binary search tree ready"
    public var activeValue: String?
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Binary search tree ready"
        activeValue = nil
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        activeValue = event.value
        lastEvent = event
        let name = event.meta?["name"] ?? "Tree"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "tree-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            let updated = rebuilt.map { node in
                var copy = node
                let highlighted = node.value == event.value || node.value == event.secondaryValue
                copy.highlighted = highlighted && node.value != "·"
                if highlighted {
                    copy.sourceLine = event.sourceLine ?? copy.sourceLine
                }
                return copy
            }
            structures[name] = updated
            nodes = updated
        }
    }

    public func makeView() -> some View {
        TreeCanvas(visualizer: self)
    }
}

struct TreeCanvas: View {
    @Bindable var visualizer: TreeVisualizer

    private func pointerFor(index: Int, node: VizNode) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else { return nil }
        let type = event.type.lowercased()
        
        if node.value == event.value {
            switch type {
            case "insert":
                return ("INSERTED", PlaygroundTheme.accent)
            case "delete":
                return ("DELETING", PlaygroundTheme.danger)
            case "search", "find":
                return ("FOUND", PlaygroundTheme.accent)
            default:
                break
            }
        }
        
        if node.highlighted {
            switch type {
            case "search", "find", "delete", "insert":
                return ("COMPARE", PlaygroundTheme.accentSecondary)
            case "traverse", "traverseinorder", "traversepreorder", "traversepostorder":
                return ("VISIT", PlaygroundTheme.nodeHighlight)
            default:
                return ("ACTIVE", PlaygroundTheme.nodeHighlight)
            }
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Tree")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleTreeLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleTreeLayout(visualizer.structures[name] ?? [])
                                    .frame(height: 180)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func singleTreeLayout(_ nodes: [VizNode]) -> some View {
        GeometryReader { geo in
            let layout = TreeLayout.positions(nodes: nodes.map(\.value), in: geo.size)
            ZStack {
                ForEach(Array(layout.edges.enumerated()), id: \.offset) { _, edge in
                    Path { path in
                        path.move(to: edge.from)
                        path.addLine(to: edge.to)
                    }
                    .stroke(PlaygroundTheme.accent.opacity(0.5), lineWidth: 2)
                }
                ForEach(Array(zip(nodes, layout.points).enumerated()), id: \.element.0.id) { index, pair in
                    let (node, point) = pair
                    if node.value != "·" {
                        InteractiveNodeChip(node: node, width: 48, height: 40)
                            .position(point)
                            .transition(.playgroundInsert)
                            .animation(PlaygroundTheme.springBouncy, value: nodes)
                        
                        if let pointer = pointerFor(index: index, node: node) {
                            PointerOverlayView(label: pointer.label, color: pointer.color, direction: .down)
                                .position(x: point.x, y: point.y - 32)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

enum TreeLayout {
    struct Edge { let from: CGPoint; let to: CGPoint }

    static func positions(nodes: [String], in size: CGSize) -> (points: [CGPoint], edges: [Edge]) {
        guard !nodes.isEmpty else { return ([], []) }
        var points: [CGPoint] = []
        var edges: [Edge] = []
        let count = nodes.count
        let levels = Int(log2(Double(max(count, 1)))) + 1

        for index in 0..<count {
            let level = Int(log2(Double(index + 1)))
            let levelStart = (1 << level) - 1
            let positionInLevel = index - levelStart
            let slots = 1 << level
            let y = size.height * CGFloat(level + 1) / CGFloat(levels + 1)
            let x = size.width * CGFloat(positionInLevel + 1) / CGFloat(slots + 1)
            points.append(CGPoint(x: x, y: y))
        }

        for index in 0..<count {
            let left = 2 * index + 1
            let right = 2 * index + 2
            if left < count, nodes[index] != "·", nodes[left] != "·" {
                edges.append(Edge(from: points[index], to: points[left]))
            }
            if right < count, nodes[index] != "·", nodes[right] != "·" {
                edges.append(Edge(from: points[index], to: points[right]))
            }
        }
        return (points, edges)
    }
}

public struct TreeModule: DSAModule {
    public let id = "tree"
    public let title = "Tree"
    public let systemImage = "leaf"
    public let structureKey = "tree"
    public let bootstrapCode = "let tree = AnimatedBinaryTree<Int>()"

    public init() {}

    public var starterCode: String {
        """
        // Binary Search Tree playground — insert / search / traverse / delete
        let tree = AnimatedBinaryTree<Int>()

        tree.insert(50)
        tree.insert(30)
        tree.insert(70)
        tree.insert(20)
        tree.insert(40)
        tree.insert(60)
        tree.insert(80)
        _ = tree.search(40)
        tree.traverseInorder()
        tree.delete(30)
        _ = tree.search(30)
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "insert", title: "Insert", systemImage: "plus", snippet: "tree.insert(Int.random(in: 1...99))"),
            .init(id: "search", title: "Search", systemImage: "magnifyingglass", snippet: "_ = tree.search(50)"),
            .init(id: "traverse", title: "Inorder", systemImage: "arrow.left.and.right", snippet: "tree.traverseInorder()"),
            .init(id: "delete", title: "Delete", systemImage: "trash", snippet: "tree.delete(50)"),
            .init(id: "insertMultiple", title: "Insert Multiple", systemImage: "plus.square.fill.on.square.fill", snippet: "tree.insert(25); tree.insert(75); tree.insert(12)")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        TreeVisualizer()
    }
}
