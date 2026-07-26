import SwiftUI
import DSACore

/// Per-view Show/Hide toggle + Adjust toggle used on every pane header.
struct PaneHeaderControls: View {
    @Binding var isVisible: Bool
    @Binding var isAdjusting: Bool
    var showAdjust: Bool = true
    var onOpenWindow: (() -> Void)? = nil
    var onDock: (() -> Void)? = nil
    var isDetached: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let onOpenWindow, let onDock {
                Button {
                    if isDetached {
                        onDock()
                    } else {
                        onOpenWindow()
                    }
                } label: {
                    Image(systemName: isDetached ? "rectangle.inset.filled" : "macwindow.badge.plus")
                }
                .buttonStyle(.borderless)
                .help(isDetached ? "Dock in main window" : "Open in new window")
            }
        }
        .controlSize(.small)
        .labelsHidden()
    }
}

struct PaneAdjustHint: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(PlaygroundTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(PlaygroundTheme.accent.opacity(0.12))
    }
}
