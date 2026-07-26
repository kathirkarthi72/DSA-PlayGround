import Foundation

/// Persisted playground preferences (JSON in Application Support).
struct AppSettings: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var general: General
    var editor: Editor
    var layout: Layout
    var intelligence: Intelligence

    struct General: Codable, Equatable, Sendable {
        var autoRunAfterAdapt: Bool
        var animationSpeed: Double
    }

    struct Editor: Codable, Equatable, Sendable {
        var showLineNumbers: Bool
        var enableCodeFolding: Bool
        var showDiagnosticsPanel: Bool
        var editorFontSize: Double
    }

    struct Layout: Codable, Equatable, Sendable {
        var showSidebar: Bool
        var showBuiltInActions: Bool
        var showEditor: Bool
        var showVisualizer: Bool
        var showConsole: Bool
        var showAIPanel: Bool
        var sidebarWidth: Double
        var editorMinWidth: Double
        var visualizerMinWidth: Double
        var aiPanelWidth: Double
        var consoleHeight: Double
        var builtInBarHeight: Double
    }

    struct Intelligence: Codable, Equatable, Sendable {
        var useAICompletion: Bool
    }

    static let currentSchemaVersion = 1

    static let `default` = AppSettings(
        schemaVersion: currentSchemaVersion,
        general: .init(
            autoRunAfterAdapt: true,
            animationSpeed: 1.0
        ),
        editor: .init(
            showLineNumbers: true,
            enableCodeFolding: true,
            showDiagnosticsPanel: true,
            editorFontSize: 13
        ),
        layout: .init(
            showSidebar: true,
            showBuiltInActions: true,
            showEditor: true,
            showVisualizer: true,
            showConsole: true,
            showAIPanel: true,
            sidebarWidth: 220,
            editorMinWidth: 320,
            visualizerMinWidth: 300,
            aiPanelWidth: 300,
            consoleHeight: 140,
            builtInBarHeight: 44
        ),
        intelligence: .init(
            useAICompletion: true
        )
    )

    /// Clamp out-of-range values after decode / manual edits.
    mutating func sanitize() {
        schemaVersion = Self.currentSchemaVersion
        general.animationSpeed = min(2.5, max(0.4, general.animationSpeed))
        editor.editorFontSize = min(18, max(11, editor.editorFontSize.rounded()))
        layout.sidebarWidth = min(420, max(160, layout.sidebarWidth))
        layout.editorMinWidth = min(700, max(240, layout.editorMinWidth))
        layout.visualizerMinWidth = min(700, max(220, layout.visualizerMinWidth))
        layout.aiPanelWidth = min(520, max(220, layout.aiPanelWidth))
        layout.consoleHeight = min(360, max(80, layout.consoleHeight))
        layout.builtInBarHeight = min(80, max(36, layout.builtInBarHeight))
    }
}
