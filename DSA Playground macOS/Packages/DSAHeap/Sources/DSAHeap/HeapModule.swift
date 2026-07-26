import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class HeapVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Heap ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Heap ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "Heap"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "heap-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            nodes = rebuilt
        }
    }

    public func makeView() -> some View {
        HeapCanvas(visualizer: self)
    }
}

struct HeapCanvas: View {
    @Bindable var visualizer: HeapVisualizer

    private func pointerFor(index: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else { return nil }
        let type = event.type.lowercased()
        
        if event.index == index {
            switch type {
            case "insert":
                return ("INSERTED", PlaygroundTheme.accent)
            case "extract":
                return ("EXTRACTING", PlaygroundTheme.danger)
            default:
                break
            }
        }
        
        if event.highlight.contains(index) {
            switch type {
            case "swap", "siftup", "siftdown", "heapify":
                return ("SWAP/SIFT", PlaygroundTheme.accentSecondary)
            case "compare":
                return ("COMPARE", PlaygroundTheme.accent)
            default:
                return ("ACTIVE", PlaygroundTheme.nodeHighlight)
            }
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Heap")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleHeapLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleHeapLayout(visualizer.structures[name] ?? [])
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
    private func singleHeapLayout(_ nodes: [VizNode]) -> some View {
        GeometryReader { geo in
            let layout = HeapLayout.positions(count: nodes.count, in: geo.size)
            ZStack {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, _ in
                    if index > 0 {
                        let parent = (index - 1) / 2
                        Path { path in
                            path.move(to: layout[parent])
                            path.addLine(to: layout[index])
                        }
                        .stroke(PlaygroundTheme.accent.opacity(0.45), lineWidth: 2)
                        .animation(PlaygroundTheme.springSnappy, value: nodes)
                    }
                }
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    InteractiveNodeChip(node: node, width: 48, height: 40)
                        .position(layout[index])
                        .transition(.playgroundInsert)
                        .animation(PlaygroundTheme.springBouncy, value: nodes)
                    
                    if let pointer = pointerFor(index: index) {
                        PointerOverlayView(label: pointer.label, color: pointer.color, direction: .down)
                            .position(x: layout[index].x, y: layout[index].y - 32)
                    }
                }
            }
        }
        .padding()
    }
}

enum HeapLayout {
    static func positions(count: Int, in size: CGSize) -> [CGPoint] {
        guard count > 0 else { return [] }
        var points: [CGPoint] = []
        let levels = Int(log2(Double(count))) + 1
        for index in 0..<count {
            let level = Int(log2(Double(index + 1)))
            let levelStart = (1 << level) - 1
            let positionInLevel = index - levelStart
            let slots = 1 << level
            let y = size.height * CGFloat(level + 1) / CGFloat(levels + 1)
            let x = size.width * CGFloat(positionInLevel + 1) / CGFloat(slots + 1)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}

public struct HeapModule: DSAModule {
    public let id = "heap"
    public let title = "Heap"
    public let systemImage = "pyramid"
    public let structureKey = "heap"
    public let bootstrapCode = "var heap = AnimatedHeap<Int>(kind: .min)"

    public init() {}

    public var starterCode: String {
        """
        // Heap playground — insert / extract
        var heap = AnimatedHeap<Int>(kind: .min)

        heap.insert(10)
        heap.insert(5)
        heap.insert(20)
        heap.insert(3)
        _ = heap.extract()
        heap.insert(15)
        _ = heap.extract()
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "insert", title: "Insert", systemImage: "plus", snippet: "heap.insert(Int.random(in: 1...50))"),
            .init(id: "extract", title: "Extract", systemImage: "minus", snippet: "_ = heap.extract()"),
            .init(id: "insertMultiple", title: "Insert Multiple", systemImage: "plus.square.fill.on.square.fill", snippet: "heap.insert(30); heap.insert(10); heap.insert(40)"),
            .init(id: "extractAll", title: "Extract All (Clear)", systemImage: "trash", snippet: "while !heap.isEmpty { _ = heap.extract() }")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        HeapVisualizer()
    }
}
