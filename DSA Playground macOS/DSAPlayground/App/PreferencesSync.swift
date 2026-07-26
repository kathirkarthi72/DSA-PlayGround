import SwiftUI

/// Keeps `settings.json` in sync when menus, toolbars, or resize handles change live state.
struct PreferencesSyncModifier: ViewModifier {
    var store: AppSettingsStore
    var session: PlaygroundSession
    var layout: PanelLayoutState

    func body(content: Content) -> some View {
        content
            .modifier(SessionPreferencesSync(store: store, session: session, layout: layout))
            .modifier(LayoutVisibilityPreferencesSync(store: store, session: session, layout: layout))
            .modifier(LayoutSizePreferencesSync(store: store, session: session, layout: layout))
    }
}

private struct SessionPreferencesSync: ViewModifier {
    var store: AppSettingsStore
    var session: PlaygroundSession
    var layout: PanelLayoutState

    func body(content: Content) -> some View {
        content
            .onChange(of: session.autoRunAfterAdapt) { _, _ in persist() }
            .onChange(of: session.animationSpeed) { _, _ in persist() }
            .onChange(of: session.showLineNumbers) { _, _ in persist() }
            .onChange(of: session.enableCodeFolding) { _, _ in persist() }
            .onChange(of: session.showDiagnosticsPanel) { _, _ in persist() }
            .onChange(of: session.useAICompletion) { _, _ in persist() }
            .onChange(of: session.editorFontSize) { _, _ in persist() }
    }

    private func persist() {
        store.capture(from: session, layout: layout)
    }
}

private struct LayoutVisibilityPreferencesSync: ViewModifier {
    var store: AppSettingsStore
    var session: PlaygroundSession
    var layout: PanelLayoutState

    func body(content: Content) -> some View {
        content
            .onChange(of: layout.showSidebar) { _, _ in persist() }
            .onChange(of: layout.showBuiltInActions) { _, _ in persist() }
            .onChange(of: layout.showEditor) { _, _ in persist() }
            .onChange(of: layout.showVisualizer) { _, _ in persist() }
            .onChange(of: layout.showConsole) { _, _ in persist() }
            .onChange(of: layout.showAIPanel) { _, _ in persist() }
    }

    private func persist() {
        store.capture(from: session, layout: layout)
    }
}

private struct LayoutSizePreferencesSync: ViewModifier {
    var store: AppSettingsStore
    var session: PlaygroundSession
    var layout: PanelLayoutState

    func body(content: Content) -> some View {
        content
            .onChange(of: layout.sidebarWidth) { _, _ in persist() }
            .onChange(of: layout.editorMinWidth) { _, _ in persist() }
            .onChange(of: layout.visualizerMinWidth) { _, _ in persist() }
            .onChange(of: layout.aiPanelWidth) { _, _ in persist() }
            .onChange(of: layout.consoleHeight) { _, _ in persist() }
            .onChange(of: layout.builtInBarHeight) { _, _ in persist() }
    }

    private func persist() {
        store.capture(from: session, layout: layout)
    }
}

extension View {
    func syncPreferences(
        store: AppSettingsStore,
        session: PlaygroundSession,
        layout: PanelLayoutState
    ) -> some View {
        modifier(PreferencesSyncModifier(store: store, session: session, layout: layout))
    }
}
