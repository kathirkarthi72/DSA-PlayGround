import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    /// 1-based caret / focused line.
    var focusedLine: Int = 1
    /// 1-based line to emphasize (hover or click from canvas / diagnostic).
    var emphasizedLine: Int? = nil
    /// Soft context lines around the canvas / running selection.
    var previousContextLine: Int? = nil
    var nextContextLine: Int? = nil
    var useAppleIntelligenceCompletion: Bool = true
    var completionEngine: CodeCompletionEngine = CodeCompletionEngine()
    var intelligence: AppleIntelligenceGenerator? = nil
    var diagnostics: [CodeDiagnostic] = []
    var showLineNumbers: Bool = true
    var enableCodeFolding: Bool = true
    var foldableLines: Set<Int> = []
    var foldedLines: Set<Int> = []
    /// Monospace editor font size in points.
    var fontSize: CGFloat = 13
    var onToggleFold: ((Int) -> Void)? = nil
    var onCaretChange: ((Int, Int, String) -> Void)? = nil
    var onRunSelection: ((String) -> Void)? = nil
    var onAskIntelligence: ((String) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedFontSize: CGFloat {
        min(18, max(11, fontSize))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> EditorContainerView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        let palette = EditorChrome.Syntax.palette(for: colorScheme)
        let appearance = EditorChrome.nsAppearance(for: colorScheme)

        let textView = PlaygroundTextView(frame: .zero)
        textView.completionDelegate = context.coordinator
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.appearance = appearance
        let fontSize = resolvedFontSize
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = palette.foreground
        textView.backgroundColor = palette.background
        textView.insertionPointColor = palette.caret
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selection,
            .foregroundColor: palette.foreground
        ]
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 2
            style.paragraphSpacing = 0
            return style
        }()
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: palette.foreground,
            .backgroundColor: NSColor.clear
        ]
        scrollView.appearance = appearance
        scrollView.backgroundColor = palette.background
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.heightTracksTextView = false
            container.lineFragmentPadding = 4
            container.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.string = text
        scrollView.documentView = textView

        let gutter = LineNumberRulerView(frame: .zero)
        gutter.textView = textView
        gutter.appearance = appearance
        let editor = EditorContainerView(scrollView: scrollView, gutterView: gutter)
        editor.showsLineNumbers = showLineNumbers
        editor.appearance = appearance

        context.coordinator.textView = textView
        context.coordinator.ruler = gutter
        gutter.onToggleFold = { [weak coordinator = context.coordinator] line in
            coordinator?.parent.onToggleFold?(line)
        }

        context.coordinator.lastColorScheme = colorScheme
        context.coordinator.syncTextLayout(scrollView: scrollView, textView: textView)
        context.coordinator.applyChromeColors(scrollView: scrollView, textView: textView)
        context.coordinator.applyHighlight(
            to: textView,
            focusedLine: focusedLine,
            emphasizedLine: emphasizedLine,
            previousLine: previousContextLine,
            nextLine: nextContextLine
        )
        context.coordinator.updateRuler()
        context.coordinator.reportCaret(from: textView)
        return editor
    }

    func updateNSView(_ editor: EditorContainerView, context: Context) {
        let scrollView = editor.scrollView
        guard let textView = scrollView.documentView as? PlaygroundTextView else { return }
        context.coordinator.parent = self
        context.coordinator.textView = textView
        context.coordinator.engine.useAppleIntelligence = useAppleIntelligenceCompletion
        context.coordinator.ruler = editor.gutterView
        editor.showsLineNumbers = showLineNumbers
        scrollView.hasHorizontalScroller = false

        context.coordinator.syncTextLayout(scrollView: scrollView, textView: textView)
        editor.gutterView.onToggleFold = { line in self.onToggleFold?(line) }

        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }

        let textChanged = textView.string != text
        let focusChanged = context.coordinator.lastFocusedLine != focusedLine
        let emphasizeChanged = context.coordinator.lastEmphasizedLine != emphasizedLine
        let contextLinesChanged =
            context.coordinator.lastPreviousLine != previousContextLine
            || context.coordinator.lastNextLine != nextContextLine
        let diagnosticsChanged = context.coordinator.lastDiagnostics != diagnostics
        let schemeChanged = context.coordinator.lastColorScheme != colorScheme
        let fontChanged = abs(context.coordinator.lastFontSize - resolvedFontSize) > 0.1
        if schemeChanged {
            context.coordinator.lastColorScheme = colorScheme
            context.coordinator.applyChromeColors(scrollView: scrollView, textView: textView)
        }
        if fontChanged {
            context.coordinator.lastFontSize = resolvedFontSize
        }

        // Always apply externally-driven text (tab / Question Bank switches). Avoid
        // pushing the old NSTextView buffer back through the binding first.
        if textChanged {
            textView.string = text
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.inlineSuggestion = nil
            textView.hideCompletionList()
            textView.breakUndoCoalescing()
        }

        if textChanged || focusChanged || emphasizeChanged || contextLinesChanged || diagnosticsChanged || schemeChanged || fontChanged {
            context.coordinator.applyHighlight(
                to: textView,
                focusedLine: focusedLine,
                emphasizedLine: emphasizedLine,
                previousLine: previousContextLine,
                nextLine: nextContextLine
            )
            if focusChanged, let emphasizedLine, emphasizedLine == focusedLine {
                // Canvas click / running line — follow caret + scroll.
                context.coordinator.moveCaret(to: focusedLine, in: textView)
                context.coordinator.scrollToLine(focusedLine, in: textView)
            } else if let line = emphasizedLine, emphasizeChanged {
                // Hover preview — scroll only.
                context.coordinator.scrollToLine(line, in: textView)
            }
        }
        context.coordinator.updateRuler()
    }

    final class Coordinator: NSObject, NSTextViewDelegate, PlaygroundTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: PlaygroundTextView?
        weak var ruler: LineNumberRulerView?
        var lastFocusedLine: Int = 1
        var lastEmphasizedLine: Int?
        var lastPreviousLine: Int?
        var lastNextLine: Int?
        var lastDiagnostics: [CodeDiagnostic] = []
        var lastColorScheme: ColorScheme?
        var lastFontSize: CGFloat = 13
        let engine = CodeCompletionEngine()
        private var debounceTask: Task<Void, Never>?
        private var activeInline: CodeSuggestion?
        private var popupSelection = 0

        init(_ parent: CodeEditorView) {
            self.parent = parent
            self.engine.useAppleIntelligence = parent.useAppleIntelligenceCompletion
            self.lastFontSize = parent.resolvedFontSize
        }

        var fontSize: CGFloat { parent.resolvedFontSize }

        func reportCaret(from textView: PlaygroundTextView) {
            let caret = textView.caretLineAndColumn()
            parent.onCaretChange?(caret.line, caret.column, textView.selectedPlainText)
        }

        func applyChromeColors(scrollView: NSScrollView, textView: NSTextView) {
            let appearance = EditorChrome.nsAppearance(for: parent.colorScheme)
            let palette = EditorChrome.Syntax.palette(for: appearance)
            scrollView.appearance = appearance
            textView.appearance = appearance
            scrollView.backgroundColor = palette.background
            textView.backgroundColor = palette.background
            textView.textColor = palette.foreground
            textView.insertionPointColor = palette.caret
            textView.selectedTextAttributes = [
                .backgroundColor: palette.selection,
                .foregroundColor: palette.foreground
            ]
            textView.typingAttributes = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: palette.foreground,
                .backgroundColor: NSColor.clear
            ]
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            (textView as? PlaygroundTextView)?.applyAppearanceColors()
            if let container = scrollView.superview as? EditorContainerView {
                container.appearance = appearance
                container.gutterView.appearance = appearance
                container.gutterView.needsDisplay = true
            } else {
                ruler?.appearance = appearance
                ruler?.needsDisplay = true
            }
            textView.needsDisplay = true
        }

        /// Pin text view width to the clip view so glyphs stay on-screen (no huge horizontal document).
        func syncTextLayout(scrollView: NSScrollView, textView: NSTextView) {
            let desiredInset = NSSize(width: 8, height: 10)
            if textView.textContainerInset != desiredInset {
                textView.textContainerInset = desiredInset
            }

            // Clear any leftover clip insets from older ruler-based layout.
            let clipView = scrollView.contentView
            if clipView.contentInsets.left != 0
                || clipView.contentInsets.right != 0
                || clipView.contentInsets.top != 0
                || clipView.contentInsets.bottom != 0 {
                clipView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            }

            let usableWidth = max(clipView.bounds.width, 1)
            var frame = textView.frame
            if abs(frame.size.width - usableWidth) > 0.5 {
                frame.size.width = usableWidth
                textView.frame = frame
            }
            if let container = textView.textContainer {
                container.widthTracksTextView = true
                let size = NSSize(width: usableWidth, height: CGFloat.greatestFiniteMagnitude)
                if container.containerSize != size {
                    container.containerSize = size
                }
            }
            // Kill accidental horizontal scroll offsets that hide the code.
            let origin = clipView.bounds.origin
            if origin.x > 0.5 {
                clipView.scroll(to: NSPoint(x: 0, y: origin.y))
                scrollView.reflectScrolledClipView(clipView)
            }
            ruler?.needsDisplay = true
            textView.needsDisplay = true
        }

        func updateRuler() {
            guard let ruler else { return }
            var map: [Int: CodeDiagnostic.Severity] = [:]
            for diagnostic in parent.diagnostics {
                if map[diagnostic.line] == .error { continue }
                map[diagnostic.line] = diagnostic.severity
            }
            ruler.diagnosticsByLine = map
            ruler.foldableStartLines = parent.enableCodeFolding ? parent.foldableLines : []
            ruler.foldedStartLines = parent.enableCodeFolding ? parent.foldedLines : []
            ruler.focusedLine = parent.focusedLine
            ruler.needsDisplay = true
            lastDiagnostics = parent.diagnostics
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PlaygroundTextView else { return }
            parent.text = textView.string
            let caret = textView.caretLineAndColumn()
            applyHighlight(
                to: textView,
                focusedLine: caret.line,
                emphasizedLine: parent.emphasizedLine,
                previousLine: parent.previousContextLine,
                nextLine: parent.nextContextLine
            )
            updateRuler()
            reportCaret(from: textView)
            scheduleCompletion(from: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? PlaygroundTextView ?? textView else { return }
            let caret = textView.caretLineAndColumn()
            applyHighlight(
                to: textView,
                focusedLine: caret.line,
                emphasizedLine: parent.emphasizedLine,
                previousLine: parent.previousContextLine,
                nextLine: parent.nextContextLine
            )
            ruler?.focusedLine = caret.line
            reportCaret(from: textView)
            textView.needsDisplay = true
            ruler?.needsDisplay = true
        }

        func playgroundTextViewRunSelection(_ textView: PlaygroundTextView) {
            let selected = textView.selectedPlainText
            guard !selected.isEmpty else { return }
            parent.onRunSelection?(selected)
        }

        func playgroundTextViewAskIntelligence(_ textView: PlaygroundTextView) {
            let selected = textView.selectedPlainText
            guard !selected.isEmpty else { return }
            parent.onAskIntelligence?(selected)
        }

        // MARK: - Completion delegate

        func playgroundTextViewDidRequestCompletion(_ textView: PlaygroundTextView) {
            scheduleCompletion(from: textView)
        }

        func playgroundTextViewDidAcceptInline(_ textView: PlaygroundTextView) {
            let suggestion = textView.selectedSuggestion ?? activeInline
            guard let suggestion else {
                textView.hideCompletionList()
                return
            }
            accept(suggestion, in: textView)
        }

        func playgroundTextViewDidDismissCompletion(_ textView: PlaygroundTextView) {
            textView.inlineSuggestion = nil
            activeInline = nil
            textView.hideCompletionList()
            debounceTask?.cancel()
        }

        func playgroundTextViewMoveCompletion(_ textView: PlaygroundTextView, delta: Int) {
            guard !textView.completionItems.isEmpty else { return }
            popupSelection = (popupSelection + delta + textView.completionItems.count) % textView.completionItems.count
            textView.updateCompletionSelection(popupSelection)
            let item = textView.completionItems[popupSelection]
            activeInline = item
            textView.inlineSuggestion = item.insertText
            textView.needsDisplay = true
        }

        private func scheduleCompletion(from textView: PlaygroundTextView) {
            debounceTask?.cancel()
            let source = textView.string
            let cursor = textView.selectedRange().location

            let local = engine.localSuggestions(source: source, cursor: cursor)
            popupSelection = 0
            if !local.isEmpty {
                textView.showCompletionList(local, selectedIndex: 0)
                activeInline = local[0]
                textView.inlineSuggestion = local[0].insertText
            } else if let prediction = engine.localInlinePrediction(source: source, cursor: cursor) {
                textView.hideCompletionList()
                activeInline = prediction
                textView.inlineSuggestion = prediction.insertText
            } else {
                textView.hideCompletionList()
                textView.inlineSuggestion = nil
                activeInline = nil
            }
            textView.needsDisplay = true

            guard parent.useAppleIntelligenceCompletion,
                  let intelligence = parent.intelligence else { return }

            debounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard let self, !Task.isCancelled else { return }
                guard intelligence.isAvailable else { return }
                guard let textView = self.textView else { return }
                let current = textView.string
                let currentCursor = textView.selectedRange().location
                guard current == source, currentCursor == cursor else { return }

                if let aiText = await intelligence.completeSwiftCode(
                    source: current,
                    cursor: currentCursor,
                    context: nil
                ) {
                    guard !Task.isCancelled, self.textView === textView else { return }
                    let suggestion = CodeSuggestion(
                        insertText: aiText,
                        displayText: aiText.replacingOccurrences(of: "\n", with: "↵ "),
                        detail: "Apple Intelligence",
                        description: "On-device suggestion for the next code at the caret.",
                        kind: .appleIntelligence,
                        replacePrefixLength: 0
                    )
                    self.activeInline = suggestion
                    textView.inlineSuggestion = aiText
                    if textView.completionItems.isEmpty {
                        textView.showCompletionList([suggestion], selectedIndex: 0)
                        self.popupSelection = 0
                    } else {
                        var items = textView.completionItems
                        items.insert(suggestion, at: 0)
                        textView.showCompletionList(Array(items.prefix(10)), selectedIndex: 0)
                        self.popupSelection = 0
                    }
                    textView.needsDisplay = true
                }
            }
        }

        private func accept(_ suggestion: CodeSuggestion, in textView: PlaygroundTextView) {
            var range = textView.selectedRange()
            if suggestion.replacePrefixLength > 0 {
                let start = max(0, range.location - suggestion.replacePrefixLength)
                range = NSRange(location: start, length: range.location - start)
            }
            if textView.shouldChangeText(in: range, replacementString: suggestion.insertText) {
                textView.replaceCharacters(in: range, with: suggestion.insertText)
                textView.didChangeText()
            }
            let newLocation = range.location + (suggestion.insertText as NSString).length
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            textView.inlineSuggestion = nil
            activeInline = nil
            textView.hideCompletionList()
            parent.text = textView.string
            let caret = (textView as? PlaygroundTextView)?.caretLineAndColumn().line ?? parent.focusedLine
            applyHighlight(
                to: textView,
                focusedLine: caret,
                emphasizedLine: parent.emphasizedLine,
                previousLine: parent.previousContextLine,
                nextLine: parent.nextContextLine
            )
        }

        func applyHighlight(
            to textView: NSTextView,
            focusedLine: Int,
            emphasizedLine: Int?,
            previousLine: Int? = nil,
            nextLine: Int? = nil
        ) {
            guard let storage = textView.textStorage else { return }
            lastFocusedLine = focusedLine
            lastEmphasizedLine = emphasizedLine
            lastPreviousLine = previousLine
            lastNextLine = nextLine

            let palette = EditorChrome.Syntax.palette(for: parent.colorScheme)
            let full = NSRange(location: 0, length: storage.length)
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let paragraph = textView.defaultParagraphStyle ?? NSParagraphStyle.default

            storage.beginEditing()
            storage.setAttributes([
                .font: font,
                .foregroundColor: palette.foreground,
                .backgroundColor: NSColor.clear,
                .paragraphStyle: paragraph
            ], range: full)

            // Keywords — cyan (Xcode-like template)
            let keywords = [
                "import", "protocol", "func", "final", "class", "struct", "enum", "extension",
                "var", "let", "weak", "unowned", "lazy", "static", "override", "required",
                "public", "private", "fileprivate", "internal", "open", "mutating", "nonmutating",
                "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
                "return", "break", "continue", "defer", "throw", "throws", "rethrows", "try",
                "catch", "as", "is", "in", "where", "self", "Self", "super", "init", "deinit",
                "subscript", "typealias", "associatedtype", "some", "any", "async", "await",
                "actor", "isolated", "nonisolated", "consuming", "borrowing", "inout", "get", "set"
            ]
            for keyword in keywords {
                colorMatches(
                    pattern: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b",
                    in: storage,
                    range: full,
                    color: palette.keyword
                )
            }

            // Literals — purple
            for literal in ["true", "false", "nil"] {
                colorMatches(
                    pattern: "\\b\(literal)\\b",
                    in: storage,
                    range: full,
                    color: palette.number
                )
            }
            colorMatches(
                pattern: "\\b[0-9]+(\\.[0-9]+)?\\b",
                in: storage,
                range: full,
                color: palette.number
            )

            // Types — peach (capitalized identifiers + known DSA / Foundation names)
            colorMatches(
                pattern: "\\b[A-Z][A-Za-z0-9_]*\\b",
                in: storage,
                range: full,
                color: palette.type
            )

            // Attributes — gold
            colorMatches(
                pattern: "@[A-Za-z_][A-Za-z0-9_]*",
                in: storage,
                range: full,
                color: palette.attribute
            )

            // Strings — coral (before comments so comments win)
            colorMatches(
                pattern: "\"([^\"\\\\]|\\\\.)*\"",
                in: storage,
                range: full,
                color: palette.string
            )

            // Comments — muted slate (last so they override)
            colorMatches(
                pattern: "//[^\\n]*",
                in: storage,
                range: full,
                color: palette.comment
            )
            colorMatches(
                pattern: "/\\*[\\s\\S]*?\\*/",
                in: storage,
                range: full,
                color: palette.comment
            )

            let ns = storage.string as NSString
            // Previous / next canvas context (softest).
            if let previousLine, previousLine > 0, previousLine != emphasizedLine {
                applyLineBackground(
                    previousLine,
                    in: storage,
                    ns: ns,
                    color: EditorChrome.Syntax.contextLineHighlight
                )
            }
            if let nextLine, nextLine > 0, nextLine != emphasizedLine, nextLine != previousLine {
                applyLineBackground(
                    nextLine,
                    in: storage,
                    ns: ns,
                    color: EditorChrome.Syntax.contextLineHighlight
                )
            }
            // Caret focused line (subtle).
            if focusedLine > 0 {
                applyLineBackground(
                    focusedLine,
                    in: storage,
                    ns: ns,
                    color: palette.focusedLineHighlight
                )
            }
            // Canvas / diagnostic emphasis (stronger; may override focus).
            if let emphasizedLine, emphasizedLine > 0 {
                applyLineBackground(
                    emphasizedLine,
                    in: storage,
                    ns: ns,
                    color: palette.lineHighlight
                )
            }

            let errorColor = NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.38, alpha: 1)
            let warningColor = NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.28, alpha: 1)
            for diagnostic in parent.diagnostics {
                var line = 1
                var location = 0
                while location <= ns.length {
                    let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                    if line == diagnostic.line {
                        let safe = NSIntersectionRange(lineRange, NSRange(location: 0, length: ns.length))
                        if safe.length > 0 {
                            let color = diagnostic.severity == .error ? errorColor : warningColor
                            storage.addAttributes([
                                .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
                                .underlineColor: color,
                                .backgroundColor: color.withAlphaComponent(0.12)
                            ], range: safe)
                        }
                        break
                    }
                    if lineRange.length == 0 { break }
                    location = NSMaxRange(lineRange)
                    line += 1
                    if location >= ns.length { break }
                }
            }

            storage.endEditing()
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: palette.foreground,
                .backgroundColor: NSColor.clear,
                .paragraphStyle: paragraph
            ]
            textView.needsDisplay = true
        }

        private func colorMatches(
            pattern: String,
            in storage: NSTextStorage,
            range: NSRange,
            color: NSColor
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        private func applyLineBackground(
            _ targetLine: Int,
            in storage: NSTextStorage,
            ns: NSString,
            color: NSColor
        ) {
            var line = 1
            var location = 0
            while location <= ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                if line == targetLine {
                    let safe = NSIntersectionRange(lineRange, NSRange(location: 0, length: ns.length))
                    if safe.length > 0 {
                        storage.addAttribute(.backgroundColor, value: color, range: safe)
                    } else if ns.length == 0 {
                        // empty document — nothing to paint
                    }
                    break
                }
                if lineRange.length == 0 { break }
                location = NSMaxRange(lineRange)
                line += 1
                if location >= ns.length { break }
            }
        }

        func moveCaret(to line: Int, in textView: NSTextView) {
            guard line > 0 else { return }
            let ns = textView.string as NSString
            var current = 1
            var location = 0
            while location <= ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                if current == line {
                    textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    return
                }
                if lineRange.length == 0 { break }
                location = NSMaxRange(lineRange)
                current += 1
                if location >= ns.length { break }
            }
        }

        func scrollToLine(_ line: Int, in textView: NSTextView) {
            let ns = textView.string as NSString
            var current = 1
            var location = 0
            while location < ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                if current == line {
                    // Prefer vertical-only scroll so we don't shove code off-screen horizontally.
                    if let layoutManager = textView.layoutManager,
                       let textContainer = textView.textContainer {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                        var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                        lineRect.origin.x = 0
                        lineRect = lineRect.offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
                        textView.scrollToVisible(lineRect)
                    } else {
                        textView.scrollRangeToVisible(lineRange)
                    }
                    if let scrollView = textView.enclosingScrollView {
                        let origin = scrollView.contentView.bounds.origin
                        if abs(origin.x) > 0.5 {
                            scrollView.contentView.scroll(to: NSPoint(x: 0, y: origin.y))
                            scrollView.reflectScrolledClipView(scrollView.contentView)
                        }
                    }
                    return
                }
                location = NSMaxRange(lineRange)
                current += 1
            }
        }
    }
}
