import AppKit

/// Line-number gutter drawn as a sibling of the text scroll view (not NSRulerView).
/// NSRulerView + SwiftUI often tiles incorrectly and paints the gutter over the code.
final class LineNumberRulerView: NSView {
    weak var textView: NSTextView?
    var diagnosticsByLine: [Int: CodeDiagnostic.Severity] = [:]
    var foldableStartLines: Set<Int> = []
    var foldedStartLines: Set<Int> = []
    /// 1-based caret line for gutter emphasis.
    var focusedLine: Int = 1
    var onToggleFold: ((Int) -> Void)?

    static let thickness: CGFloat = 48

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)
            palette.gutterBackground.setFill()
            bounds.fill()
            return
        }

        let palette = EditorChrome.Syntax.palette(for: effectiveAppearance)

        palette.gutterBackground.setFill()
        bounds.fill()

        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        sep.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        palette.gutterSeparator.setStroke()
        sep.lineWidth = 1
        sep.stroke()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard glyphRange.length > 0 || !textView.string.isEmpty else { return }

        // Map text-container Y into gutter coordinates (both flipped).
        let textOriginInGutter = convert(textView.textContainerOrigin, from: textView)

        var lineNumber = 1
        let ns = textView.string as NSString
        if glyphRange.length > 0, glyphRange.location < layoutManager.numberOfGlyphs {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
            if charIndex > 0 {
                lineNumber = ns.substring(to: min(charIndex, ns.length)).components(separatedBy: "\n").count
            }
        }

        var glyphIndex = glyphRange.location
        let glyphEnd = NSMaxRange(glyphRange)
        while glyphIndex < glyphEnd, glyphIndex < layoutManager.numberOfGlyphs {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineY = lineRect.minY + textOriginInGutter.y
            let y = lineY + (lineRect.height - 13) / 2

            let isFocused = lineNumber == focusedLine
            if isFocused {
                let band = NSRect(
                    x: 0,
                    y: lineY,
                    width: bounds.width,
                    height: lineRect.height
                )
                palette.focusedLineHighlight.setFill()
                band.fill()
            }

            if foldableStartLines.contains(lineNumber) {
                let folded = foldedStartLines.contains(lineNumber)
                let symbol = folded ? "›" : "⌄"
                let foldAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: palette.foldMarker
                ]
                (symbol as NSString).draw(at: NSPoint(x: 5, y: y - 1), withAttributes: foldAttrs)
            }

            if let severity = diagnosticsByLine[lineNumber] {
                let color: NSColor = severity == .error
                    ? NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.38, alpha: 1)
                    : NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.28, alpha: 1)
                let dot = NSBezierPath(ovalIn: NSRect(x: 16, y: y + 3, width: 5, height: 5))
                color.setFill()
                dot.fill()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: isFocused ? .semibold : .regular),
                .foregroundColor: isFocused
                    ? palette.foreground.withAlphaComponent(0.85)
                    : palette.gutterText
            ]
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: bounds.width - size.width - 8, y: y), withAttributes: attrs)

            glyphIndex = NSMaxRange(lineGlyphRange)
            lineNumber += 1
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if point.x > 16 {
            super.mouseDown(with: event)
            return
        }
        let textPoint = textView.convert(event.locationInWindow, from: nil)
        let glyphIndex = layoutManager.glyphIndex(for: textPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let ns = textView.string as NSString
        let line = ns.substring(to: min(charIndex, ns.length)).components(separatedBy: "\n").count
        if foldableStartLines.contains(line) {
            onToggleFold?(line)
            needsDisplay = true
        }
    }
}
