import Foundation
import Observation

/// Loads / saves [`AppSettings`] as JSON and keeps the live session + layout in sync.
@MainActor
@Observable
final class AppSettingsStore {
    private(set) var settings: AppSettings
    private(set) var fileURL: URL

    private var isApplying = false

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.settings = Self.load(from: url) ?? .default
        self.settings.sanitize()
        // Ensure a file exists on first launch.
        if !FileManager.default.fileExists(atPath: url.path) {
            persist()
        }
    }

    static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = root.appendingPathComponent("DSA Playground", isDirectory: true)
        return dir.appendingPathComponent("settings.json", isDirectory: false)
    }

    // MARK: - Mutate / reset

    func update(_ body: (inout AppSettings) -> Void) {
        var next = settings
        body(&next)
        next.sanitize()
        guard next != settings else { return }
        settings = next
        persist()
    }

    func resetToDefaults() {
        settings = .default
        persist()
    }

    func replace(_ newSettings: AppSettings) {
        var next = newSettings
        next.sanitize()
        settings = next
        persist()
    }

    // MARK: - Live state sync

    func apply(to session: WorkspaceViewModel, layout: PanelLayoutState) {
        isApplying = true
        defer { isApplying = false }

        session.autoRunAfterAdapt = settings.general.autoRunAfterAdapt
        session.animationSpeed = settings.general.animationSpeed

        session.showLineNumbers = settings.editor.showLineNumbers
        session.enableCodeFolding = settings.editor.enableCodeFolding
        session.showDiagnosticsPanel = settings.editor.showDiagnosticsPanel
        session.editorFontSize = settings.editor.editorFontSize

        session.useAICompletion = settings.intelligence.useAICompletion

        layout.showSidebar = settings.layout.showSidebar
        layout.showBuiltInActions = settings.layout.showBuiltInActions
        layout.showEditor = settings.layout.showEditor
        layout.showVisualizer = settings.layout.showVisualizer
        layout.showConsole = settings.layout.showConsole
        layout.showAIPanel = settings.layout.showAIPanel
        layout.sidebarWidth = settings.layout.sidebarWidth
        layout.editorMinWidth = settings.layout.editorMinWidth
        layout.visualizerMinWidth = settings.layout.visualizerMinWidth
        layout.aiPanelWidth = settings.layout.aiPanelWidth
        layout.consoleHeight = settings.layout.consoleHeight
        layout.builtInBarHeight = settings.layout.builtInBarHeight
    }

    /// Call after menus / toolbars mutate session or layout so JSON stays current.
    func capture(from session: WorkspaceViewModel, layout: PanelLayoutState) {
        guard !isApplying else { return }

        var next = settings
        next.general.autoRunAfterAdapt = session.autoRunAfterAdapt
        next.general.animationSpeed = session.animationSpeed

        next.editor.showLineNumbers = session.showLineNumbers
        next.editor.enableCodeFolding = session.enableCodeFolding
        next.editor.showDiagnosticsPanel = session.showDiagnosticsPanel
        next.editor.editorFontSize = session.editorFontSize

        next.intelligence.useAICompletion = session.useAICompletion

        next.layout.showSidebar = layout.showSidebar
        next.layout.showBuiltInActions = layout.showBuiltInActions
        next.layout.showEditor = layout.showEditor
        next.layout.showVisualizer = layout.showVisualizer
        next.layout.showConsole = layout.showConsole
        next.layout.showAIPanel = layout.showAIPanel
        next.layout.sidebarWidth = layout.sidebarWidth
        next.layout.editorMinWidth = layout.editorMinWidth
        next.layout.visualizerMinWidth = layout.visualizerMinWidth
        next.layout.aiPanelWidth = layout.aiPanelWidth
        next.layout.consoleHeight = layout.consoleHeight
        next.layout.builtInBarHeight = layout.builtInBarHeight

        next.sanitize()
        guard next != settings else { return }
        settings = next
        persist()
    }

    /// Update settings, persist, and push into the live session/layout.
    func updateAndApply(
        session: WorkspaceViewModel,
        layout: PanelLayoutState,
        _ body: (inout AppSettings) -> Void
    ) {
        update(body)
        apply(to: session, layout: layout)
    }

    func resetToDefaultsAndApply(session: WorkspaceViewModel, layout: PanelLayoutState) {
        resetToDefaults()
        apply(to: session, layout: layout)
        // Layout reset also clears ephemeral adjust/detach flags.
        layout.resetLayout()
        // Re-apply persisted defaults after resetLayout overwrote sizes/visibility.
        apply(to: session, layout: layout)
    }

    // MARK: - Disk

    private func persist() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Preferences are best-effort; keep the in-memory values even if disk write fails.
            NSLog("AppSettingsStore: failed to save \(fileURL.path): \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> AppSettings? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            decoded.sanitize()
            return decoded
        } catch {
            NSLog("AppSettingsStore: failed to load \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
}
