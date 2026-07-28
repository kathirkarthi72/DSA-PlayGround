import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class QueueVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Queue ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Queue ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "Queue"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "queue-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            nodes = rebuilt
        }
    }

    public func makeView() -> some View {
        QueueCanvas(visualizer: self)
    }
}

struct QueueCanvas: View {
    @Bindable var visualizer: QueueVisualizer

    private func pointerFor(index: Int, count: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else {
            if index == 0 {
                return ("FRONT", PlaygroundTheme.accent)
            } else if index == count - 1 {
                return ("REAR", PlaygroundTheme.accentSecondary)
            }
            return nil
        }
        let type = event.type.lowercased()
        
        if event.index == index {
            switch type {
            case "enqueue":
                return ("ENQUEUED", PlaygroundTheme.accentSecondary)
            case "dequeue":
                return ("DEQUEUED", PlaygroundTheme.danger)
            case "peek":
                return ("PEEK", PlaygroundTheme.accent)
            default:
                break
            }
        }
        
        if event.highlight.contains(index) {
            return ("ACTIVE", PlaygroundTheme.nodeHighlight)
        }
        
        if index == 0 {
            return ("FRONT", PlaygroundTheme.accent)
        } else if index == count - 1 {
            return ("REAR", PlaygroundTheme.accentSecondary)
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption, event: visualizer.lastEvent, nodes: visualizer.nodes) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Queue")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleQueueLayout(firstPair.value)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .padding(.leading, 20)
                                
                                singleQueueLayout(visualizer.structures[name] ?? [])
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func singleQueueLayout(_ nodes: [VizNode]) -> some View {
        HStack(spacing: 12) {
            Text("FRONT")
                .font(.caption.weight(.bold))
                .foregroundStyle(PlaygroundTheme.accent)
                .rotationEffect(.degrees(-90))
                .offset(y: 15)
            
            HStack(spacing: 10) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    VStack(spacing: 6) {
                        if let pointer = pointerFor(index: index, count: nodes.count) {
                            PointerOverlayView(label: pointer.label, color: pointer.color, direction: .down)
                                .frame(height: 24)
                        } else {
                            Spacer()
                                .frame(height: 24)
                        }
                        InteractiveNodeChip(node: node)
                    }
                    .transition(.playgroundSlide)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PlaygroundTheme.accent.opacity(0.35), lineWidth: 1.5)
            )
            .animation(PlaygroundTheme.springBouncy, value: nodes)
            
            Text("REAR")
                .font(.caption.weight(.bold))
                .foregroundStyle(PlaygroundTheme.accentSecondary)
                .rotationEffect(.degrees(-90))
                .offset(y: 15)
        }
    }
}

public struct QueueModule: DSAModule {
    public let id = "queue"
    public let title = "Queue"
    public let systemImage = "line.3.horizontal"
    public let structureKey = "queue"
    public let bootstrapCode = "var queue = AnimatedQueue<String>()"

    public init() {}

    public var starterCode: String {
        """
        // Queue playground — enqueue / dequeue / peek
        var queue = AnimatedQueue<String>()

        queue.enqueue("A")
        queue.enqueue("B")
        queue.enqueue("C")
        _ = queue.peek()
        _ = queue.dequeue()
        queue.enqueue("D")
        _ = queue.dequeue()
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "enqueue", title: "Enqueue", systemImage: "plus.circle", snippet: "queue.enqueue(String(UnicodeScalar(Int.random(in: 65...90))!))"),
            .init(id: "peek", title: "Peek", systemImage: "eye", snippet: "_ = queue.peek()"),
            .init(id: "dequeue", title: "Dequeue", systemImage: "minus.circle", snippet: "_ = queue.dequeue()"),
            .init(id: "enqueueMultiple", title: "Enqueue Multiple", systemImage: "plus.square.fill.on.square.fill", snippet: "queue.enqueue(\"X\"); queue.enqueue(\"Y\"); queue.enqueue(\"Z\")"),
            .init(id: "dequeueAll", title: "Dequeue All (Clear)", systemImage: "trash", snippet: "while !queue.isEmpty { _ = queue.dequeue() }")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        QueueVisualizer()
    }
}
