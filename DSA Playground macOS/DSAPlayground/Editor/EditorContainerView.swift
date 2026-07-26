import AppKit

/// Side-by-side gutter + scrollable text editor.
/// Avoids NSRulerView, which SwiftUI-hosted NSScrollView often tiles over the code.
final class EditorContainerView: NSView {
    let scrollView: NSScrollView
    let gutterView: LineNumberRulerView
    private var gutterWidthConstraint: NSLayoutConstraint?
    private var scrollLeadingConstraint: NSLayoutConstraint?

    var showsLineNumbers: Bool = true {
        didSet { updateGutterVisibility() }
    }

    init(scrollView: NSScrollView, gutterView: LineNumberRulerView) {
        self.scrollView = scrollView
        self.gutterView = gutterView
        super.init(frame: .zero)
        wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        gutterView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutterView)
        addSubview(scrollView)

        let gutterWidth = gutterView.widthAnchor.constraint(equalToConstant: LineNumberRulerView.thickness)
        let scrollLeading = scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor)
        gutterWidthConstraint = gutterWidth
        scrollLeadingConstraint = scrollLeading

        NSLayoutConstraint.activate([
            gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterWidth,

            scrollLeading,
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewBoundsChanged),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewBoundsChanged),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func updateGutterVisibility() {
        let width = showsLineNumbers ? LineNumberRulerView.thickness : 0
        gutterWidthConstraint?.constant = width
        gutterView.isHidden = !showsLineNumbers
        gutterView.needsDisplay = true
        needsLayout = true
    }

    @objc private func clipViewBoundsChanged() {
        gutterView.needsDisplay = true
    }
}
