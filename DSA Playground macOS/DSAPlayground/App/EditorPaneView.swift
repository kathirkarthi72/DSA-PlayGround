import SwiftUI
import DSACore

struct EditorPaneView: View {
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    var onOpenWindow: (() -> Void)? = nil
    var onDock: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
            breadcrumbBar
            if layout.adjustEditor {
                adjustControls
            }
            CodeEditorView(
                text: Binding(
                    get: { session.sourceCode },
                    set: { newValue in
                        let old = session.sourceCode
                        session.sourceCode = newValue
                        session.handleEditorChange(from: old, to: newValue)
                    }
                ),
                focusedLine: session.focusedLine,
                emphasizedLine: session.activeSourceLine ?? session.selectedDiagnostic?.line,
                previousContextLine: session.previousSourceLine,
                nextContextLine: session.nextSourceLine,
                useAppleIntelligenceCompletion: session.useAICompletion,
                intelligence: session.intelligence,
                diagnostics: session.activeDiagnostics,
                showLineNumbers: session.showLineNumbers,
                enableCodeFolding: session.enableCodeFolding,
                foldableLines: session.foldableLines(in: session.sourceCode),
                foldedLines: session.foldedStartLines(for: session.activeDocumentID),
                fontSize: CGFloat(session.editorFontSize),
                onToggleFold: { line in session.toggleFold(at: line) },
                onCaretChange: { line, column, selected in
                    session.updateCaret(line: line, column: column, selectedText: selected)
                },
                onRunSelection: { code in
                    session.runSelection(code)
                },
                onAskIntelligence: { code in
                    layout.showAIPanel = true
                    session.aiMode = .ask
                    session.updateCaret(
                        line: session.focusedLine,
                        column: session.focusedColumn,
                        selectedText: code
                    )
                    session.askAppleIntelligence(code: code)
                }
            )
            // Recreate the AppKit text view when the active tab changes so Question Bank /
            // file switches always show the selected document's source.
            .id(session.activeDocumentID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if session.showDiagnosticsPanel {
                diagnosticsPanel
            }

            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EditorChrome.editorBackground)
    }

    private var hasSelection: Bool {
        !session.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text("Ln \(session.focusedLine), Col \(session.focusedColumn)")
                .font(.system(size: 11).monospacedDigit())
            Text("Spaces: 4")
                .font(.system(size: 11))
            Text("UTF-8")
                .font(.system(size: 11))
            Text("Swift")
                .font(.system(size: 11))
            Spacer()
            Text(session.selectedModule.title)
                .font(.system(size: 11, weight: .medium))
            
            Divider()
                .frame(height: 12)
            
            Button {
                layout.showConsole.toggle()
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(layout.showConsole ? EditorChrome.primaryText : EditorChrome.mutedText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Toggle Console (⌃⌘5)")
        }
        .foregroundStyle(EditorChrome.mutedText)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 24)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(EditorChrome.separator).frame(height: 1)
        }
    }

    // MARK: - Tab bar (Xcode-style)

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(session.documents) { document in
                        fileTab(document)
                    }
                }
            }

            Button {
                session.addDocument()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorChrome.mutedText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New file tab (⌘T)")

            Spacer(minLength: 8)

            editorToolbarButtons
        }
        .frame(height: 36)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorChrome.separator).frame(height: 1)
        }
    }

    private func fileTab(_ document: EditorDocument) -> some View {
        let selected = document.id == session.activeDocumentID
        return HStack(spacing: 7) {
            SwiftFileIcon(size: 13)

            Button(document.name) {
                session.selectDocument(id: document.id)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: selected ? .medium : .regular))
            .foregroundStyle(selected ? EditorChrome.primaryText : EditorChrome.mutedText)
            .lineLimit(1)

            if session.documents.count > 1 {
                Button {
                    session.closeDocument(id: document.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(EditorChrome.mutedText.opacity(selected ? 0.9 : 0.55))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close tab (⌘W)")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(selected ? EditorChrome.activeTabBackground : Color.clear)
        .overlay(alignment: .bottom) {
            if selected {
                Rectangle()
                    .fill(Color(red: 0.35, green: 0.55, blue: 0.95))
                    .frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            if !selected {
                Rectangle()
                    .fill(EditorChrome.separator)
                    .frame(width: 1)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        HStack(spacing: 6) {
            breadcrumbSegment("DSAPlayground")
            breadcrumbChevron
            breadcrumbSegment(session.selectedModule.title)
            breadcrumbChevron
            HStack(spacing: 5) {
                SwiftFileIcon(size: 12)
                Text(activeDocumentName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(EditorChrome.primaryText)
                    .lineLimit(1)
            }

            Text("·")
                .foregroundStyle(EditorChrome.mutedText.opacity(0.5))
            Text("L\(session.focusedLine)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(EditorChrome.mutedText)

            if let line = session.activeSourceLine {
                Text("·")
                    .foregroundStyle(EditorChrome.mutedText.opacity(0.5))
                Button("Canvas L\(line)") {
                    session.jumpToSourceLine(line)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.28))
                .help("Jump canvas to this line")

                if let prev = session.previousSourceLine {
                    Button("prev \(prev)") {
                        session.jumpToSourceLine(prev)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(EditorChrome.mutedText)
                    .help("Run canvas up to previous line")
                }
                if let next = session.nextSourceLine {
                    Button("next \(next)") {
                        session.jumpToSourceLine(next)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(EditorChrome.mutedText)
                    .help("Run canvas up to next line")
                }
            }

            Spacer(minLength: 8)

            if session.activeDiagnostics.contains(where: { $0.severity == .error }) {
                Label("\(session.activeDiagnostics.filter { $0.severity == .error }.count)", systemImage: "xmark.octagon.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PlaygroundTheme.danger)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorChrome.separator).frame(height: 1)
        }
    }

    private var activeDocumentName: String {
        session.documents.first(where: { $0.id == session.activeDocumentID })?.name ?? "main.swift"
    }

    private func breadcrumbSegment(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(EditorChrome.mutedText)
    }

    private var breadcrumbChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(EditorChrome.mutedText.opacity(0.55))
    }

    // MARK: - Trailing toolbar

    private var editorToolbarButtons: some View {
        HStack(spacing: 2) {
            if hasSelection {
                Button {
                    session.runSelection()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PlaygroundTheme.accent)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Run selection (⌥⌘R)")
                .transition(.opacity)
            }

            PaneHeaderControls(
                isVisible: $layout.showEditor,
                isAdjusting: $layout.adjustEditor,
                onOpenWindow: onOpenWindow,
                onDock: onDock,
                isDetached: layout.editorDetached
            )
        }
        .padding(.trailing, 8)
    }

    private var adjustControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            PaneAdjustHint(text: "Adjust: drag the center split · min width \(Int(layout.editorMinWidth))")
            HStack {
                Text("Min width")
                    .font(.caption2)
                    .foregroundStyle(EditorChrome.mutedText)
                Slider(value: $layout.editorMinWidth, in: 240...700, step: 10)
                Text("\(Int(layout.editorMinWidth))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(EditorChrome.mutedText)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .background(EditorChrome.tabBarBackground.opacity(0.9))
    }

    // MARK: - Problems

    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Problems", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.accentSecondary)
                Text("\(session.activeDiagnostics.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(EditorChrome.mutedText)
                Spacer()
                Button("Refresh") { session.refreshDiagnostics() }
                    .controlSize(.small)
                Button {
                    session.showDiagnosticsPanel = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(EditorChrome.mutedText)
                }
                .buttonStyle(.plain)
            }

            if session.activeDiagnostics.isEmpty {
                Text("No errors or warnings in this file.")
                    .font(.caption)
                    .foregroundStyle(EditorChrome.mutedText)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(session.activeDiagnostics) { diagnostic in
                            diagnosticRow(diagnostic)
                        }
                    }
                }
                .frame(maxHeight: 130)
            }
        }
        .padding(10)
        .background(EditorChrome.tabBarBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(EditorChrome.separator).frame(height: 1)
        }
    }

    private func diagnosticRow(_ diagnostic: CodeDiagnostic) -> some View {
        let selected = session.selectedDiagnosticID == diagnostic.id
        let color: Color = diagnostic.severity == .error ? PlaygroundTheme.danger : PlaygroundTheme.accentSecondary
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: diagnostic.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("L\(diagnostic.line): \(diagnostic.message)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EditorChrome.primaryText)
                        .textSelection(.enabled)
                    Text(diagnostic.suggestion)
                        .font(.caption2)
                        .foregroundStyle(EditorChrome.mutedText)
                        .textSelection(.enabled)
                }
                Spacer()
                if diagnostic.hasFix {
                    Button("Accept") {
                        session.acceptFix(for: diagnostic)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlaygroundTheme.accent)
                    .controlSize(.small)
                    .help("Apply suggested fix (⌘⌥⏎)")
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? color.opacity(0.12) : EditorChrome.editorBackground.opacity(0.85))
        )
        .onTapGesture {
            session.selectedDiagnosticID = diagnostic.id
            session.selectCanvasSourceLine(diagnostic.line)
        }
    }
}
