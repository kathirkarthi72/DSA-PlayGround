import SwiftUI
import DSACore

struct CodeEditorWindow: View {
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EditorPaneView(
            session: session,
            layout: layout,
            onOpenWindow: nil,
            onDock: {
                layout.dockEditor()
                dismiss()
            }
        )
        .frame(minWidth: 520, minHeight: 420)
        .navigationTitle("Code Editor")
        .onAppear {
            layout.editorDetached = true
            layout.showEditor = true
        }
        .onDisappear {
            if layout.editorDetached {
                layout.editorDetached = false
            }
        }
    }
}

struct VisualizationWindow: View {
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VisualizerPaneView(
            session: session,
            layout: layout,
            onOpenWindow: nil,
            onDock: {
                layout.dockVisualizer()
                dismiss()
            }
        )
        .frame(minWidth: 560, minHeight: 420)
        .navigationTitle("Canvas View")
        .onAppear {
            layout.visualizerDetached = true
            layout.showVisualizer = true
        }
        .onDisappear {
            if layout.visualizerDetached {
                layout.visualizerDetached = false
            }
        }
    }
}

struct DetachedPanePlaceholder: View {
    let title: String
    let systemImage: String
    let message: String
    let openActionTitle: String
    let onOpen: () -> Void
    let onDock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(PlaygroundTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(PlaygroundTheme.text)
            Text(message)
                .font(.callout)
                .foregroundStyle(PlaygroundTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 10) {
                Button(openActionTitle, action: onOpen)
                    .buttonStyle(.borderedProminent)
                    .tint(PlaygroundTheme.accent)
                Button("Dock Here", action: onDock)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlaygroundTheme.background)
    }
}
