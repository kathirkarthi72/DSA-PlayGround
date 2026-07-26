import SwiftUI

/// macOS Settings window (⌘,) — changes auto-apply and persist to JSON.
struct SettingsView: View {
    @Bindable var store: AppSettingsStore
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    @State private var confirmReset = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            editorTab
                .tabItem { Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right") }

            layoutTab
                .tabItem { Label("Layout", systemImage: "rectangle.split.3x1") }

            intelligenceTab
                .tabItem { Label("Intelligence", systemImage: "sparkles") }
        }
        .frame(width: 520, height: 420)
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            resetBar
        }
        .alert("Reset All Settings?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Defaults", role: .destructive) {
                store.resetToDefaultsAndApply(session: session, layout: layout)
            }
        } message: {
            Text("This restores General, Editor, Layout, and Intelligence preferences to their defaults and saves settings.json.")
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Auto-run after adapt / generate", isOn: generalBinding(\.autoRunAfterAdapt))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation speed")
                        Spacer()
                        Text(String(format: "%.1fx", store.settings.general.animationSpeed))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: generalBinding(\.animationSpeed),
                        in: 0.4...2.5,
                        step: 0.1
                    )
                }
            } header: {
                Text("Playground")
            } footer: {
                Text("Changes apply immediately and are saved to settings.json.")
            }

            Section("Storage") {
                LabeledContent("File") {
                    Text(store.fileURL.path)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var editorTab: some View {
        Form {
            Section("Display") {
                Toggle("Show line numbers", isOn: editorBinding(\.showLineNumbers))
                Toggle("Enable code folding", isOn: editorBinding(\.enableCodeFolding))
                Toggle("Show Problems panel", isOn: editorBinding(\.showDiagnosticsPanel))
            }

            Section("Font") {
                Stepper(
                    value: editorBinding(\.editorFontSize),
                    in: 11...18,
                    step: 1
                ) {
                    HStack {
                        Text("Editor font size")
                        Spacer()
                        Text("\(Int(store.settings.editor.editorFontSize)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var layoutTab: some View {
        Form {
            Section("Visible panes") {
                Toggle("Sidebar", isOn: layoutBinding(\.showSidebar))
                Toggle("Built-in actions", isOn: layoutBinding(\.showBuiltInActions))
                Toggle("Code editor", isOn: layoutBinding(\.showEditor))
                Toggle("Canvas View", isOn: layoutBinding(\.showVisualizer))
                Toggle("Console", isOn: layoutBinding(\.showConsole))
                Toggle("Apple Intelligence panel", isOn: layoutBinding(\.showAIPanel))
            }

            Section("Sizes") {
                sizeSlider("Sidebar width", value: layoutBinding(\.sidebarWidth), range: 160...420)
                sizeSlider("Editor min width", value: layoutBinding(\.editorMinWidth), range: 240...700)
                sizeSlider("Canvas View min width", value: layoutBinding(\.visualizerMinWidth), range: 220...700)
                sizeSlider("AI panel width", value: layoutBinding(\.aiPanelWidth), range: 220...520)
                sizeSlider("Console height", value: layoutBinding(\.consoleHeight), range: 80...360)
                sizeSlider("Built-in bar height", value: layoutBinding(\.builtInBarHeight), range: 36...80)
            }
        }
    }

    private var intelligenceTab: some View {
        Form {
            Section {
                Toggle("Apple Intelligence code completion", isOn: intelligenceBinding(\.useAICompletion))
            } header: {
                Text("Completion")
            } footer: {
                Text("When enabled, the editor can offer local and on-device Apple Intelligence suggestions while you type. Explanations still use the Ask panel.")
            }
        }
    }

    private var resetBar: some View {
        HStack {
            Text("Settings auto-save on change")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset to Defaults…") {
                confirmReset = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Bindings

    private func generalBinding<Value>(
        _ keyPath: WritableKeyPath<AppSettings.General, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.settings.general[keyPath: keyPath] },
            set: { newValue in
                store.updateAndApply(session: session, layout: layout) { settings in
                    settings.general[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func editorBinding<Value>(
        _ keyPath: WritableKeyPath<AppSettings.Editor, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.settings.editor[keyPath: keyPath] },
            set: { newValue in
                store.updateAndApply(session: session, layout: layout) { settings in
                    settings.editor[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func layoutBinding<Value>(
        _ keyPath: WritableKeyPath<AppSettings.Layout, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.settings.layout[keyPath: keyPath] },
            set: { newValue in
                store.updateAndApply(session: session, layout: layout) { settings in
                    settings.layout[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func intelligenceBinding<Value>(
        _ keyPath: WritableKeyPath<AppSettings.Intelligence, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.settings.intelligence[keyPath: keyPath] },
            set: { newValue in
                store.updateAndApply(session: session, layout: layout) { settings in
                    settings.intelligence[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func sizeSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 1)
        }
    }
}
