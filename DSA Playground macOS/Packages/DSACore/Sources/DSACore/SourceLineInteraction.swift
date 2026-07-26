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
        var claimed = Set<String>()
        return values.enumerated().map { index, value in
            let id = "\(idPrefix)-\(index)"
            var sourceLine = previous.first(where: { $0.id == id })?.sourceLine

            if sourceLine == nil {
                if let match = previous.first(where: { $0.value == value && !claimed.contains($0.id) }) {
                    sourceLine = match.sourceLine
                    claimed.insert(match.id)
                }
            } else {
                claimed.insert(id)
            }

            if highlights.contains(index) || event.index == index {
                sourceLine = event.sourceLine ?? sourceLine
            }

            return VizNode(
                id: id,
                value: value,
                highlighted: highlights.contains(index),
                sourceLine: sourceLine
            )
        }
    }
}
