import AppKit

protocol PlaygroundTextViewDelegate: AnyObject {
    func playgroundTextViewDidRequestCompletion(_ textView: PlaygroundTextView)
    func playgroundTextViewDidAcceptInline(_ textView: PlaygroundTextView)
    func playgroundTextViewDidDismissCompletion(_ textView: PlaygroundTextView)
    func playgroundTextViewMoveCompletion(_ textView: PlaygroundTextView, delta: Int)
    func playgroundTextViewRunSelection(_ textView: PlaygroundTextView)
    func playgroundTextViewAskIntelligence(_ textView: PlaygroundTextView)
}

final class PlaygroundTextView: NSTextView {
    weak var completionDelegate: PlaygroundTextViewDelegate?

    /// Ghost / inline prediction shown after the caret.
    var inlineSuggestion: String? {
        didSet {
            needsDisplay = true
        }
    }

    var completionItems: [CodeSuggestion] = []
    private var completionTable: NSTableView?
    private var completionScroll: NSScrollView?
    private var completionPanel: NSPanel?
    private var selectedCompletionIndex: Int = 0

    func applyAppearanceColors() {
        let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)
        completionPanel?.appearance = appearance ?? effectiveAppearance
        completionPanel?.backgroundColor = palette.background.withAlphaComponent(0.98)
        completionTable?.reloadData()
        needsDisplay = true
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isAutomaticTextCompletionEnabled = false
        allowsUndo = true
        isRichText = true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu(title: "Editor")
        let selected = selectedRange()
        if selected.length > 0 {
            menu.insertItem(NSMenuItem.separator(), at: 0)
            let ask = NSMenuItem(
                title: "Ask Apple Intelligence",
                action: #selector(askIntelligenceMenuAction),
                keyEquivalent: ""
            )
            ask.target = self
            menu.insertItem(ask, at: 0)
            let run = NSMenuItem(
                title: "Run Selection",
                action: #selector(runSelectionMenuAction),
                keyEquivalent: ""
            )
            run.target = self
            menu.insertItem(run, at: 0)
        }
        return menu
    }

    @objc private func runSelectionMenuAction() {
        completionDelegate?.playgroundTextViewRunSelection(self)
    }

    @objc private func askIntelligenceMenuAction() {
        completionDelegate?.playgroundTextViewAskIntelligence(self)
    }

    var selectedPlainText: String {
        let range = selectedRange()
        guard range.length > 0, range.length >= NSMaxRange(range) else { return "" }
        return (string as NSString).substring(with: range)
    }

    /// 1-based line and column for the caret (selection start).
    func caretLineAndColumn() -> (line: Int, column: Int) {
        let ns = string as NSString
        let location = min(selectedRange().location, ns.length)
        var line = 1
        var column = 1
        var i = 0
        while i < location {
            if ns.character(at: i) == 10 { // \n
                line += 1
                column = 1
            } else {
                column += 1
            }
            i += 1
        }
        return (line, column)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawInlineSuggestion()
    }

    private func drawInlineSuggestion() {
        guard let suggestion = inlineSuggestion, !suggestion.isEmpty else { return }
        let ns = string as NSString
        let caret = selectedRange().location
        guard caret <= ns.length else { return }

        let layoutManager = layoutManager
        let textContainer = textContainer
        guard let layoutManager, let textContainer else { return }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: caret)
        var fraction: CGFloat = 0
        let withoutFraction = layoutManager.lineFragmentRect(
            forGlyphAt: max(0, min(glyphIndex, max(0, layoutManager.numberOfGlyphs - 1))),
            effectiveRange: nil
        )
        let location = layoutManager.location(forGlyphAt: max(0, min(glyphIndex, max(0, layoutManager.numberOfGlyphs - 1))))
        var point = NSPoint(
            x: withoutFraction.origin.x + location.x + textContainerOrigin.x,
            y: withoutFraction.origin.y + textContainerOrigin.y
        )

        // When at end of empty doc, use insertion point.
        if ns.length == 0 {
            point = NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height)
        }
        _ = fraction

        let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: palette.gutterText.withAlphaComponent(0.85)
        ]
        let drawn = suggestion as NSString
        drawn.draw(at: point, withAttributes: attrs)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if let panel = completionPanel, panel.isVisible {
            switch event.keyCode {
            case 126: // up
                completionDelegate?.playgroundTextViewMoveCompletion(self, delta: -1)
                return
            case 125: // down
                completionDelegate?.playgroundTextViewMoveCompletion(self, delta: 1)
                return
            case 36, 48: // return / tab
                completionDelegate?.playgroundTextViewDidAcceptInline(self)
                return
            case 53: // escape
                completionDelegate?.playgroundTextViewDidDismissCompletion(self)
                return
            default:
                break
            }
        }

        // Tab accepts inline ghost suggestion when popup is hidden.
        if event.keyCode == 48, flags.isEmpty, inlineSuggestion != nil, !(completionPanel?.isVisible ?? false) {
            completionDelegate?.playgroundTextViewDidAcceptInline(self)
            return
        }

        // Escape clears ghost text.
        if event.keyCode == 53, inlineSuggestion != nil {
            inlineSuggestion = nil
            completionDelegate?.playgroundTextViewDidDismissCompletion(self)
            return
        }

        // Right arrow at end of line can accept ghost if caret at suggestion point.
        if event.keyCode == 124, flags.isEmpty, inlineSuggestion != nil {
            let caret = selectedRange().location
            if caret == string.count || (string as NSString).substring(from: caret).hasPrefix("\n") {
                completionDelegate?.playgroundTextViewDidAcceptInline(self)
                return
            }
        }

        super.keyDown(with: event)

        // Trigger completion after typing.
        if event.charactersIgnoringModifiers?.first?.isLetter == true
            || event.charactersIgnoringModifiers == "."
            || event.charactersIgnoringModifiers == "_" {
            completionDelegate?.playgroundTextViewDidRequestCompletion(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let panel = completionPanel, panel.isVisible {
            let locationInPanel = panel.contentView?.convert(event.locationInWindow, from: nil)
            if let locationInPanel, panel.contentView?.bounds.contains(locationInPanel) == true {
                // Let table handle click.
            } else {
                completionDelegate?.playgroundTextViewDidDismissCompletion(self)
            }
        }
        super.mouseDown(with: event)
    }

    func showCompletionList(_ items: [CodeSuggestion], selectedIndex: Int) {
        completionItems = items
        selectedCompletionIndex = max(0, min(selectedIndex, max(0, items.count - 1)))
        guard !items.isEmpty else {
            hideCompletionList()
            return
        }

        if completionPanel == nil {
            buildCompletionUI()
        }
        completionTable?.reloadData()
        completionTable?.selectRowIndexes(IndexSet(integer: selectedCompletionIndex), byExtendingSelection: false)

        // Position near caret.
        guard let window, let layoutManager, let textContainer else { return }
        let caret = selectedRange().location
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(caret, max(0, (string as NSString).length)))
        let fragment = layoutManager.lineFragmentRect(forGlyphAt: min(glyphIndex, max(0, layoutManager.numberOfGlyphs - 1)), effectiveRange: nil)
        let loc = layoutManager.location(forGlyphAt: min(glyphIndex, max(0, layoutManager.numberOfGlyphs - 1)))
        var caretPoint = NSPoint(x: fragment.origin.x + loc.x, y: fragment.origin.y + fragment.height)
        caretPoint = convert(caretPoint, to: nil)
        caretPoint = window.convertPoint(toScreen: caretPoint)

        let size = NSSize(width: 420, height: min(CGFloat(items.count) * 36 + 8, 280))
        var frame = NSRect(
            x: caretPoint.x,
            y: caretPoint.y - size.height - 4,
            width: size.width,
            height: size.height
        )
        if let screen = window.screen?.visibleFrame {
            if frame.minX + frame.width > screen.maxX {
                frame.origin.x = screen.maxX - frame.width - 8
            }
            if frame.minY < screen.minY {
                frame.origin.y = caretPoint.y + 18
            }
        }

        completionPanel?.setFrame(frame, display: true)
        completionPanel?.orderFront(nil)
    }

    func updateCompletionSelection(_ index: Int) {
        selectedCompletionIndex = index
        completionTable?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        completionTable?.scrollRowToVisible(index)
    }

    func hideCompletionList() {
        completionPanel?.orderOut(nil)
        completionItems = []
    }

    var selectedSuggestion: CodeSuggestion? {
        guard !completionItems.isEmpty,
              selectedCompletionIndex >= 0,
              selectedCompletionIndex < completionItems.count else {
            return nil
        }
        return completionItems[selectedCompletionIndex]
    }

    private func buildCompletionUI() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)
        panel.appearance = appearance ?? effectiveAppearance
        panel.backgroundColor = palette.background.withAlphaComponent(0.98)
        panel.hasShadow = true
        panel.isOpaque = false

        let scroll = NSScrollView(frame: panel.contentView?.bounds ?? .zero)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let table = NSTableView(frame: scroll.bounds)
        table.headerView = nil
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.rowHeight = 24
        table.target = self
        table.action = #selector(completionClicked)
        table.doubleAction = #selector(completionClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = 300
        table.addTableColumn(column)
        table.dataSource = self
        table.delegate = self

        scroll.documentView = table
        panel.contentView?.addSubview(scroll)

        completionPanel = panel
        completionScroll = scroll
        completionTable = table
    }

    @objc private func completionClicked() {
        completionDelegate?.playgroundTextViewDidAcceptInline(self)
    }
}

extension PlaygroundTextView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        completionItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = completionItems[row]
        let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)

        let title = NSTextField(labelWithString: "\(item.displayText)  ·  \(item.detail)")
        title.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        title.textColor = palette.foreground
        title.backgroundColor = .clear
        title.isBordered = false
        title.lineBreakMode = .byTruncatingTail

        let subtitle = NSTextField(labelWithString: item.description)
        subtitle.font = NSFont.systemFont(ofSize: 10)
        subtitle.textColor = palette.comment
        subtitle.backgroundColor = .clear
        subtitle.isBordered = false
        subtitle.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        return stack
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        36
    }
}
