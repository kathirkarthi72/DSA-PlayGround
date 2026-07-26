import Foundation
import SwiftUI

/// Controls visibility, sizing, and detached-window state for playground panes.
@MainActor
@Observable
final class PanelLayoutState {
    var showSidebar: Bool = true
    var showBuiltInActions: Bool = true
    var showEditor: Bool = true
    var showVisualizer: Bool = true
    var showConsole: Bool = true
    /// Persistent Apple Intelligence panel on the right.
    var showAIPanel: Bool = true

    /// When true, that pane shows its resize / adjust controls.
    var adjustSidebar: Bool = false
    var adjustBuiltInActions: Bool = false
    var adjustEditor: Bool = false
    var adjustVisualizer: Bool = false
    var adjustConsole: Bool = false
    var adjustAIPanel: Bool = false

    /// When true, the pane is primarily shown in its dedicated window.
    var editorDetached: Bool = false
    var visualizerDetached: Bool = false

    var editorMinWidth: Double = 320
    var visualizerMinWidth: Double = 300
    var aiPanelWidth: Double = 300
    var consoleHeight: Double = 140
    var builtInBarHeight: Double = 44
    var sidebarWidth: Double = 220

    var showsEmbeddedEditor: Bool {
        showEditor && !editorDetached
    }

    var showsEmbeddedVisualizer: Bool {
        showVisualizer && !visualizerDetached
    }

    func openEditorWindow() {
        editorDetached = true
        showEditor = true
    }

    func openVisualizerWindow() {
        visualizerDetached = true
        showVisualizer = true
    }

    func dockEditor() {
        editorDetached = false
        showEditor = true
    }

    func dockVisualizer() {
        visualizerDetached = false
        showVisualizer = true
    }

    func resetLayout() {
        showSidebar = true
        showBuiltInActions = true
        showEditor = true
        showVisualizer = true
        showConsole = true
        showAIPanel = true
        adjustSidebar = false
        adjustBuiltInActions = false
        adjustEditor = false
        adjustVisualizer = false
        adjustConsole = false
        adjustAIPanel = false
        editorDetached = false
        visualizerDetached = false
        editorMinWidth = 320
        visualizerMinWidth = 300
        aiPanelWidth = 300
        consoleHeight = 140
        builtInBarHeight = 44
        sidebarWidth = 220
    }
}
