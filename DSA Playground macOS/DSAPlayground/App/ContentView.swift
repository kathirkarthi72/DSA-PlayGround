import SwiftUI
import DSACore

struct ContentView: View {
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    @ObservedObject private var runner: SwiftPlaygroundRunner
    @ObservedObject private var intelligence: AppleIntelligenceGenerator
    @Environment(\.openWindow) private var openWindow

    init(session: PlaygroundSession, layout: PanelLayoutState) {
        self.session = session
        self.layout = layout
        self._runner = ObservedObject(wrappedValue: session.runner)
        self._intelligence = ObservedObject(wrappedValue: session.intelligence)
    }

    var body: some View {
        Group {
            if layout.showSidebar {
                NavigationSplitView {
                    sidebar
                } detail: {
                    mainWorkspace
                }
            } else {
                NavigationStack {
                    mainWorkspace
                }
            }
        }
        .background(PlaygroundTheme.background)
        .toolbar { navigationToolbar }
        .onReceive(NotificationCenter.default.publisher(for: .openCodeEditorWindow)) { _ in
            openEditorWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVisualizationWindow)) { _ in
            openVisualizerWindow()
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            HStack(spacing: 0) {
                if runner.isBusy {
                    Button {
                        session.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    .keyboardShortcut(".", modifiers: [.command])
                    .help("Stop execution (⌘.)")
                } else {
                    Button {
                        session.run()
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.green)
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(intelligence.isGenerating)
                    .help("Run playground (⌘R)")
                }
            }
            .padding(.trailing, 8)

            Button {
                session.resetVisualization()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .help("Reset Canvas View")

            Button {
                session.loadSample()
            } label: {
                Label("Load Sample", systemImage: "doc.text")
            }
            .help("Load sample code")

            Menu {
                Button("Adapt Current Code") {
                    session.adaptCurrentCode(autoRun: session.autoRunAfterAdapt)
                }
                Toggle("Auto-run after Adapt", isOn: $session.autoRunAfterAdapt)
            } label: {
                Label("Adapt", systemImage: "wand.and.stars")
            }
            .help("Adapt pasted code / configure auto-run")

            Menu {
                ForEach(session.selectedModule.builtInActions) { action in
                    Button {
                        session.performBuiltIn(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            } label: {
                Label("Built-in", systemImage: "bolt.circle")
            }
            .help("Run built-in algorithms / actions")
            .disabled(runner.isBusy || intelligence.isGenerating)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            panelVisibilityToggles

            Menu {
                ForEach([0.5, 1.0, 1.5, 2.0, 2.5], id: \.self) { speed in
                    Button(String(format: "%.1fx Speed", speed)) {
                        session.animationSpeed = speed
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                    Text(String(format: "%.1fx", session.animationSpeed))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                }
            }
            .menuStyle(.button)
            .help("Animation speed")

            statusBadge
        }
    }

    private var panelVisibilityToggles: some View {
        HStack(spacing: 4) {
            Toggle(isOn: $layout.showSidebar) {
                Image(systemName: "sidebar.leading")
            }
            .toggleStyle(.button)
            .help("Show/Hide Sidebar (⌃⌘1)")
            .keyboardShortcut("1", modifiers: [.command, .control])


            Toggle(isOn: $layout.showEditor) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .toggleStyle(.button)
            .help("Show/Hide Code Editor (⌃⌘3)")
            .keyboardShortcut("3", modifiers: [.command, .control])

            Toggle(isOn: $layout.showVisualizer) {
                Image(systemName: "rectangle.3.group")
            }
            .toggleStyle(.button)
            .help("Show/Hide Canvas View (⌃⌘4)")
            .keyboardShortcut("4", modifiers: [.command, .control])

            Toggle(isOn: $layout.showConsole) {
                Image(systemName: "terminal")
            }
            .toggleStyle(.button)
            .help("Show/Hide Console (⌃⌘5)")
            .keyboardShortcut("5", modifiers: [.command, .control])

            Toggle(isOn: $layout.showAIPanel) {
                Image(systemName: "sparkles")
            }
            .toggleStyle(.button)
            .help("Show/Hide Apple Intelligence (⌃⌘6)")
            .keyboardShortcut("6", modifiers: [.command, .control])
        }
        .controlSize(.small)
        .labelsHidden()
    }

    private var sidebar: some View {
        DSAFileNavigatorView(session: session, layout: layout)
            .navigationTitle("")
    }

    private var mainWorkspace: some View {
        VStack(spacing: 0) {
            workspaceSplit
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if layout.showConsole {
                Divider()
                ResizeHandle(value: $layout.consoleHeight, range: 80...360, horizontal: false)
                consolePane
                    .frame(minHeight: 80, idealHeight: layout.consoleHeight, maxHeight: layout.consoleHeight)
            }
        }
        .background(PlaygroundTheme.background)
        .navigationTitle("")
    }

    @ViewBuilder
    private var workspaceSplit: some View {
        let showEditor = layout.showsEmbeddedEditor || layout.editorDetached
        let showAI = layout.showAIPanel
        let showViz = (layout.showsEmbeddedVisualizer || layout.visualizerDetached) && (!showAI || session.conversationHasCode)

        if showEditor || showViz || showAI {
            HSplitView {
                if showEditor {
                    editorColumn
                        .frame(minWidth: layout.editorMinWidth)
                }
                if showViz {
                    visualizerColumn
                        .frame(minWidth: layout.visualizerMinWidth)
                }
                if showAI {
                    AIAssistantPanelView(
                        session: session,
                        layout: layout,
                        intelligence: intelligence
                    )
                    .frame(minWidth: 240, idealWidth: layout.aiPanelWidth)
                }
            }
        } else {
            emptyWorkspacePlaceholder
        }
    }

    @ViewBuilder
    private var editorColumn: some View {
        if layout.showsEmbeddedEditor {
            EditorPaneView(
                session: session,
                layout: layout,
                onOpenWindow: openEditorWindow,
                onDock: { layout.dockEditor() }
            )
        } else if layout.editorDetached {
            DetachedPanePlaceholder(
                title: "Code Editor",
                systemImage: "chevron.left.forwardslash.chevron.right",
                message: "Editor is open in a separate window.",
                openActionTitle: "Focus Window",
                onOpen: openEditorWindow,
                onDock: { layout.dockEditor() }
            )
        }
    }

    @ViewBuilder
    private var visualizerColumn: some View {
        if layout.showsEmbeddedVisualizer {
            VisualizerPaneView(
                session: session,
                layout: layout,
                onOpenWindow: openVisualizerWindow,
                onDock: { layout.dockVisualizer() }
            )
        } else if layout.visualizerDetached {
            DetachedPanePlaceholder(
                title: "Canvas View",
                systemImage: "rectangle.3.group",
                message: "Canvas View is open in a separate window.",
                openActionTitle: "Focus Window",
                onOpen: openVisualizerWindow,
                onDock: { layout.dockVisualizer() }
            )
        }
    }

    private var emptyWorkspacePlaceholder: some View {
        VStack(spacing: 12) {
            Text("Editor, Canvas View, and AI are hidden")
                .foregroundStyle(PlaygroundTheme.muted)
            HStack {
                Button("Show Editor") { layout.showEditor = true }
                Button("Show Canvas View") { layout.showVisualizer = true }
                Button("Show Apple Intelligence") { layout.showAIPanel = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlaygroundTheme.background)
    }

    private var builtInActionsBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Built-in")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.selectedModule.builtInActions) { action in
                            Button {
                                session.performBuiltIn(action)
                            } label: {
                                Label(action.title, systemImage: action.systemImage)
                            }
                            .buttonStyle(.bordered)
                            .disabled(runner.isBusy || intelligence.isGenerating)
                        }
                    }
                }

                PaneHeaderControls(
                    isVisible: $layout.showBuiltInActions,
                    isAdjusting: $layout.adjustBuiltInActions
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: layout.builtInBarHeight)

            if layout.adjustBuiltInActions {
                PaneAdjustHint(text: "Adjust: drag the handle below to change built-in bar height")
            }
        }
        .background(PlaygroundTheme.background)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            if intelligence.isGenerating { return ("Generating", PlaygroundTheme.accentSecondary) }
            switch runner.state {
            case .idle: return ("Idle", PlaygroundTheme.muted)
            case .compiling: return ("Compiling", PlaygroundTheme.accentSecondary)
            case .running: return ("Running", PlaygroundTheme.accent)
            case .failed: return ("Failed", PlaygroundTheme.danger)
            case .finished: return ("Finished", PlaygroundTheme.accent)
            }
        }()
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var consolePane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Console")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.muted)
                Text("·")
                    .foregroundStyle(PlaygroundTheme.muted.opacity(0.5))
                Text("Flow & output")
                    .font(.caption2)
                    .foregroundStyle(PlaygroundTheme.muted)
                Spacer()
                Text("Drag handle above to resize")
                    .font(.caption2)
                    .foregroundStyle(PlaygroundTheme.accent)
                PaneHeaderControls(
                    isVisible: $layout.showConsole,
                    isAdjusting: $layout.adjustConsole
                )
            }

            HStack {
                Text("Height")
                    .font(.caption2)
                    .foregroundStyle(PlaygroundTheme.muted)
                Slider(value: $layout.consoleHeight, in: 80...360, step: 4)
                Text("\(Int(layout.consoleHeight))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PlaygroundTheme.muted)
                    .frame(width: 36, alignment: .trailing)
            }

            HSplitView {
                ExecutionFlowPanelView(session: session)

                ScrollView {
                    Text(runner.consoleOutput.isEmpty ? "Compile, adapt, and runtime output appears here." : runner.consoleOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(runner.consoleOutput.isEmpty ? PlaygroundTheme.muted : PlaygroundTheme.text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(minWidth: 180)
                .background(PlaygroundTheme.background.opacity(0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func openEditorWindow() {
        layout.openEditorWindow()
        openWindow(id: "code-editor")
    }

    private func openVisualizerWindow() {
        layout.openVisualizerWindow()
        openWindow(id: "visualization")
    }
}
