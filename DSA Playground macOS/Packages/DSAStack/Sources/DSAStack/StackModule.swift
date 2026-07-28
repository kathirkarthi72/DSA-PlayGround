import SwiftUI
import DSACore
import Observation

@Observable
@MainActor
public final class StackVisualizer: DSAVisualizer {
    public var nodes: [VizNode] = []
    public var structures: [String: [VizNode]] = [:]
    public var caption: String = "Stack ready"
    public var lastEvent: DSAEvent? = nil

    public init() {}

    public func reset() {
        nodes = []
        structures = [:]
        caption = "Stack ready"
        lastEvent = nil
    }

    public func apply(_ event: DSAEvent) {
        caption = event.caption
        lastEvent = event
        let name = event.meta?["name"] ?? "Stack"
        if let values = event.nodes {
            let rebuilt = SourceLineLocator.rebuildNodes(
                values: values,
                idPrefix: "stack-\(name)",
                highlights: Set(event.highlight),
                previous: structures[name] ?? [],
                event: event
            )
            structures[name] = rebuilt
            nodes = rebuilt
        }
    }

    public func makeView() -> some View {
        StackCanvas(visualizer: self)
    }
}

struct StackCanvas: View {
    @Bindable var visualizer: StackVisualizer

    private func pointerFor(index: Int, count: Int) -> (label: String, color: Color)? {
        guard let event = visualizer.lastEvent else {
            if index == count - 1 {
                return ("TOP", PlaygroundTheme.accent)
            }
            return nil
        }
        let type = event.type.lowercased()
        
        if index == count - 1 {
            switch type {
            case "push":
                return ("PUSHED", PlaygroundTheme.accent)
            case "peek":
                return ("PEEK", PlaygroundTheme.accentSecondary)
            case "pop":
                return ("POPPING", PlaygroundTheme.danger)
            default:
                return ("TOP", PlaygroundTheme.accent)
            }
        }
        
        if event.highlight.contains(index) {
            return ("ACTIVE", PlaygroundTheme.nodeHighlight)
        }
        
        return nil
    }

    var body: some View {
        VisualizerChrome(caption: visualizer.caption, event: visualizer.lastEvent, nodes: visualizer.nodes) {
            if visualizer.structures.isEmpty {
                EmptyVisualizerPlaceholder(title: "Stack")
            } else if visualizer.structures.count == 1, let firstPair = visualizer.structures.first {
                singleStackLayout(firstPair.value)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(visualizer.structures.keys.sorted(), id: \.self) { name in
                            VStack(alignment: .center, spacing: 6) {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                
                                singleStackLayout(visualizer.structures[name] ?? [])
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    @ViewBuilder
    private func singleStackLayout(_ nodes: [VizNode]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(nodes.enumerated()).reversed(), id: \.element.id) { index, node in
                HStack(spacing: 8) {
                    if let pointer = pointerFor(index: index, count: nodes.count) {
                        PointerOverlayView(label: pointer.label, color: pointer.color, direction: .right)
                            .frame(width: 80, alignment: .trailing)
                    } else {
                        Spacer()
                            .frame(width: 80)
                    }
                    InteractiveNodeChip(node: node)
                }
                .transition(.playgroundInsert)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(PlaygroundTheme.muted.opacity(0.45))
                .frame(width: 88, height: 6)
            Text("BOTTOM")
                .font(.caption2)
                .foregroundStyle(PlaygroundTheme.muted)
        }
        .animation(PlaygroundTheme.springBouncy, value: nodes)
    }
}

public struct StackModule: DSAModule {
    public let id = "stack"
    public let title = "Stack"
    public let systemImage = "rectangle.stack"
    public let structureKey = "stack"
    public let bootstrapCode = "var stack = AnimatedStack<Int>()"

    public init() {}

    public var starterCode: String {
        """
        // Stack playground — push / pop / peek
        var stack = AnimatedStack<Int>()

        stack.push(10)
        stack.push(20)
        stack.push(30)
        _ = stack.peek()
        _ = stack.pop()
        stack.push(40)
        _ = stack.pop()
        _ = stack.pop()
        """
    }

    public var builtInActions: [DSABuiltInAction] {
        [
            .init(id: "push", title: "Push", systemImage: "plus", snippet: "stack.push(Int.random(in: 1...50))"),
            .init(id: "pop", title: "Pop", systemImage: "minus", snippet: "_ = stack.pop()"),
            .init(id: "peek", title: "Peek", systemImage: "eye", snippet: "_ = stack.peek()"),
            .init(id: "pushMultiple", title: "Push Multiple", systemImage: "plus.square.fill.on.square.fill", snippet: "stack.push(11); stack.push(22); stack.push(33)"),
            .init(id: "popAll", title: "Pop All (Clear)", systemImage: "trash", snippet: "while !stack.isEmpty { _ = stack.pop() }")
        ]
    }

    public func makeVisualizer() -> any DSAVisualizer {
        StackVisualizer()
    }
}
