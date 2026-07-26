import SwiftUI
import AppKit
import DSACore

struct ResizeHandle: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var horizontal: Bool = false

    @State private var dragStart: Double?

    var body: some View {
        Rectangle()
            .fill(PlaygroundTheme.muted.opacity(0.28))
            .frame(width: horizontal ? 5 : nil, height: horizontal ? nil : 5)
            .overlay(
                Capsule()
                    .fill(PlaygroundTheme.muted.opacity(0.7))
                    .frame(width: horizontal ? 3 : 28, height: horizontal ? 28 : 3)
            )
            .padding(horizontal ? .horizontal : .vertical, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        if dragStart == nil {
                            dragStart = value
                        }
                        guard let start = dragStart else { return }
                        let delta = horizontal ? Double(drag.translation.width) : Double(drag.translation.height)
                        // Prompt handle sits below the prompt: dragging down grows prompt.
                        // Console handle sits above the console: dragging down grows console.
                        value = min(max(start + delta, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
            .onHover { hovering in
                if hovering {
                    (horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("Drag to resize")
    }
}
