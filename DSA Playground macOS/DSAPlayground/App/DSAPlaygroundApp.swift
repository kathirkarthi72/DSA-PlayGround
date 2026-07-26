import SwiftUI
import DSACore
import DSAArray
import DSALinkedList
import DSAStack
import DSAQueue
import DSAHashTable
import DSAHeap
import DSATree

@main
struct DSAPlaygroundApp: App {
    @State private var session: PlaygroundSession
    @State private var layout: PanelLayoutState
    @State private var settingsStore: AppSettingsStore

    init() {
        let registry = DSAModuleRegistry(modules: [
            ArrayModule(),
            LinkedListModule(),
            StackModule(),
            QueueModule(),
            HashTableModule(),
            HeapModule(),
            TreeModule()
        ])
        let store = AppSettingsStore()
        let session = WorkspaceViewModel(registry: registry)
        let layout = PanelLayoutState()
        store.apply(to: session, layout: layout)
        _settingsStore = State(initialValue: store)
        _session = State(initialValue: session)
        _layout = State(initialValue: layout)
    }

    var body: some Scene {
        WindowGroup("DSA Playground") {
            ContentView(session: session, layout: layout)
                .frame(minWidth: 900, minHeight: 640)
                .syncPreferences(store: settingsStore, session: session, layout: layout)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandMenu("Playground") {
                Button("Run") { session.run() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Stop") { session.stop() }
                    .keyboardShortcut(".", modifiers: [.command])
                Divider()
                Button("Load Sample") { session.loadSample() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Reset Canvas View") { session.resetVisualization() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Apple Intelligence Panel") {
                    layout.showAIPanel = true
                    session.aiMode = .agent
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Adapt Paste") {
                    session.adaptCurrentCode(autoRun: session.autoRunAfterAdapt)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandMenu("View") {
                Toggle("Sidebar", isOn: Binding(
                    get: { layout.showSidebar },
                    set: { layout.showSidebar = $0 }
                ))
                .keyboardShortcut("1", modifiers: [.command, .control])

                Toggle("Built-in Actions", isOn: Binding(
                    get: { layout.showBuiltInActions },
                    set: { layout.showBuiltInActions = $0 }
                ))
                .keyboardShortcut("2", modifiers: [.command, .control])

                Toggle("Code Editor", isOn: Binding(
                    get: { layout.showEditor },
                    set: { layout.showEditor = $0 }
                ))
                .keyboardShortcut("3", modifiers: [.command, .control])

                Toggle("Canvas View", isOn: Binding(
                    get: { layout.showVisualizer },
                    set: { layout.showVisualizer = $0 }
                ))
                .keyboardShortcut("4", modifiers: [.command, .control])

                Toggle("Console", isOn: Binding(
                    get: { layout.showConsole },
                    set: { layout.showConsole = $0 }
                ))
                .keyboardShortcut("5", modifiers: [.command, .control])

                Toggle("Apple Intelligence Panel", isOn: Binding(
                    get: { layout.showAIPanel },
                    set: { layout.showAIPanel = $0 }
                ))
                .keyboardShortcut("6", modifiers: [.command, .control])

                Divider()

                Toggle("Adjust Sidebar", isOn: Binding(
                    get: { layout.adjustSidebar },
                    set: { layout.adjustSidebar = $0 }
                ))
                .keyboardShortcut("1", modifiers: [.command, .option])

                Toggle("Adjust Built-in", isOn: Binding(
                    get: { layout.adjustBuiltInActions },
                    set: { layout.adjustBuiltInActions = $0 }
                ))
                .keyboardShortcut("2", modifiers: [.command, .option])

                Toggle("Adjust Editor", isOn: Binding(
                    get: { layout.adjustEditor },
                    set: { layout.adjustEditor = $0 }
                ))
                .keyboardShortcut("3", modifiers: [.command, .option])

                Toggle("Adjust Canvas View", isOn: Binding(
                    get: { layout.adjustVisualizer },
                    set: { layout.adjustVisualizer = $0 }
                ))
                .keyboardShortcut("4", modifiers: [.command, .option])

                Toggle("Adjust Console", isOn: Binding(
                    get: { layout.adjustConsole },
                    set: { layout.adjustConsole = $0 }
                ))
                .keyboardShortcut("5", modifiers: [.command, .option])

                Divider()

                Button("Open Code Editor Window") {
                    layout.openEditorWindow()
                    NotificationCenter.default.post(name: .openCodeEditorWindow, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Open Canvas View Window") {
                    layout.openVisualizerWindow()
                    NotificationCenter.default.post(name: .openVisualizationWindow, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Divider()
                Button("Reset Layout") {
                    layout.resetLayout()
                    settingsStore.capture(from: session, layout: layout)
                }
                .keyboardShortcut("0", modifiers: [.command, .control])
            }

            CommandMenu("Editor") {
                Button("New File Tab") { session.addDocument() }
                    .keyboardShortcut("t", modifiers: [.command])

                Button("Close File Tab") {
                    session.closeDocument(id: session.activeDocumentID)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                Button("Run Selection") { session.runSelection() }
                    .keyboardShortcut("r", modifiers: [.command, .option])

                Button("Ask Apple Intelligence about Selection") {
                    layout.showAIPanel = true
                    session.aiMode = .ask
                    session.askAppleIntelligence()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Divider()

                Toggle("Line Numbers", isOn: Binding(
                    get: { session.showLineNumbers },
                    set: { session.showLineNumbers = $0 }
                ))
                .keyboardShortcut("n", modifiers: [.command, .control])

                Toggle("Code Folding", isOn: Binding(
                    get: { session.enableCodeFolding },
                    set: { session.enableCodeFolding = $0 }
                ))
                .keyboardShortcut("f", modifiers: [.command, .control])

                Toggle("Problems Panel", isOn: Binding(
                    get: { session.showDiagnosticsPanel },
                    set: { session.showDiagnosticsPanel = $0 }
                ))
                .keyboardShortcut("d", modifiers: [.command, .control])

                Toggle("AI Completion", isOn: Binding(
                    get: { session.useAICompletion },
                    set: { session.useAICompletion = $0 }
                ))
                .keyboardShortcut("a", modifiers: [.command, .control])

                Divider()

                Button("Refresh Diagnostics") { session.refreshDiagnostics() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Accept Fix") { session.acceptSelectedFix() }
                    .keyboardShortcut(.return, modifiers: [.command, .option])
            }
        }

        WindowGroup("Code Editor", id: "code-editor") {
            CodeEditorWindow(session: session, layout: layout)
                .syncPreferences(store: settingsStore, session: session, layout: layout)
        }
        .defaultSize(width: 720, height: 640)

        WindowGroup("Canvas View", id: "visualization") {
            VisualizationWindow(session: session, layout: layout)
                .syncPreferences(store: settingsStore, session: session, layout: layout)
        }
        .defaultSize(width: 800, height: 640)

        Settings {
            SettingsView(store: settingsStore, session: session, layout: layout)
        }
    }
}

extension Notification.Name {
    static let openCodeEditorWindow = Notification.Name("DSAPlayground.openCodeEditorWindow")
    static let openVisualizationWindow = Notification.Name("DSAPlayground.openVisualizationWindow")
}
