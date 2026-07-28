import SwiftUI

private struct HoverSourceLineKey: EnvironmentKey {
    static let defaultValue: Binding<Int?>? = nil
}

private struct SelectedSourceLineKey: EnvironmentKey {
    static let defaultValue: Binding<Int?>? = nil
}

public extension EnvironmentValues {
    /// 1-based source line currently hovered in Canvas View.
    var hoverSourceLine: Binding<Int?>? {
        get { self[HoverSourceLineKey.self] }
        set { self[HoverSourceLineKey.self] = newValue }
    }

    /// 1-based source line pinned by clicking a Canvas View element.
    var selectedSourceLine: Binding<Int?>? {
        get { self[SelectedSourceLineKey.self] }
        set { self[SelectedSourceLineKey.self] = newValue }
    }
}

public enum SourceLineLocator {
    /// Finds the best 1-based line for a visual value / message in source text.
    public static func line(forValue value: String?, message: String? = nil, in source: String) -> Int? {
        let lines = source.components(separatedBy: .newlines)
        if let value, !value.isEmpty {
            // Prefer executable lines that mention the value.
            for (idx, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                if line.contains(value) || line.contains("\"\(value)\"") {
                    return idx + 1
                }
            }
        }
        if let message {
            let tokens = message.split(separator: " ").map(String.init)
            for token in tokens.reversed() where token.count > 0 && token != "→" {
                if let found = line(forValue: token, in: source) {
                    return found
                }
            }
        }
        return nil
    }

    public static func rebuildNodes(
        values: [String],
        idPrefix: String,
        highlights: Set<Int>,
        previous: [VizNode],
        event: DSAEvent
    ) -> [VizNode] {
        var matches = [VizNode?](repeating: nil, count: values.count)
        var usedPreviousIndices = Set<Int>()

        // Pass 1: Match by exact index and value
        for i in 0..<values.count {
            if i < previous.count {
                let prevNode = previous[i]
                if prevNode.value == values[i] {
                    matches[i] = prevNode
                    usedPreviousIndices.insert(i)
                }
            }
        }

        // Pass 2: Match by value anywhere (e.g. for moves/swaps)
        for i in 0..<values.count {
            if matches[i] == nil {
                if let foundIndex = previous.enumerated().first(where: { idx, prevNode in
                    !usedPreviousIndices.contains(idx) && prevNode.value == values[i]
                })?.offset {
                    matches[i] = previous[foundIndex]
                    usedPreviousIndices.insert(foundIndex)
                }
            }
        }

        // Pass 3: Match by index proximity (for inline updates where value changed, like set/put)
        for i in 0..<values.count {
            if matches[i] == nil {
                if i < previous.count && !usedPreviousIndices.contains(i) {
                    var updatedNode = previous[i]
                    updatedNode.value = values[i]
                    matches[i] = updatedNode
                    usedPreviousIndices.insert(i)
                }
            }
        }

        // Pass 4: Fallback / New Node (newly inserted elements)
        return values.enumerated().map { index, value in
            let highlight = highlights.contains(index)
            
            if let matched = matches[index] {
                var node = matched
                node.highlighted = highlight
                if highlight || event.index == index {
                    node.sourceLine = event.sourceLine ?? node.sourceLine
                }
                return node
            } else {
                let newId = "\(idPrefix)-node-\(UUID().uuidString)"
                return VizNode(
                    id: newId,
                    value: value,
                    highlighted: highlight,
                    sourceLine: (highlight || event.index == index) ? event.sourceLine : nil
                )
            }
        }
    }
}
