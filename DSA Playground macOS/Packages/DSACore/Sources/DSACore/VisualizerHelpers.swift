import SwiftUI
import AppKit

public struct VizNode: Identifiable, Equatable, Hashable {
    public var id: String
    public var value: String
    public var highlighted: Bool
    /// 1-based source line associated with this visual element.
    public var sourceLine: Int?

    public init(
        id: String = UUID().uuidString,
        value: String,
        highlighted: Bool = false,
        sourceLine: Int? = nil
    ) {
        self.id = id
        self.value = value
        self.highlighted = highlighted
        self.sourceLine = sourceLine
    }
}

/// Dynamic colors that follow the system light/dark appearance.
public enum PlaygroundTheme {
    public static let background = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.12, alpha: 1)
            : NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1)
    })

    public static let panel = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.18, alpha: 1)
            : NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })

    public static let accent = Color(red: 0.12, green: 0.62, blue: 0.54)
    public static let accentSecondary = Color(red: 0.88, green: 0.52, blue: 0.16)
    public static let danger = Color(red: 0.86, green: 0.24, blue: 0.28)

    public static let nodeFill = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.30, alpha: 1)
            : NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 1)
    })

    public static let nodeHighlight = Color(red: 0.95, green: 0.62, blue: 0.28)

    public static let text = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.96, alpha: 1)
            : NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1)
    })

    public static let muted = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.55, green: 0.62, blue: 0.70, alpha: 1)
            : NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.53, alpha: 1)
    })

    public static var springSnappy: Animation {
        .spring(response: 0.42, dampingFraction: 0.72, blendDuration: 0.15)
    }

    public static var springBouncy: Animation {
        .spring(response: 0.5, dampingFraction: 0.58, blendDuration: 0.2)
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

public struct NodeChip: View {
    public let value: String
    public let highlighted: Bool
    public var focused: Bool = false
    public var width: CGFloat = 56
    public var height: CGFloat = 44

    @State private var pulse = false

    public init(
        value: String,
        highlighted: Bool,
        focused: Bool = false,
        width: CGFloat = 56,
        height: CGFloat = 44
    ) {
        self.value = value
        self.highlighted = highlighted
        self.focused = focused
        self.width = width
        self.height = height
    }

    private var isEmphasized: Bool { highlighted || focused }

    public var body: some View {
        Text(value)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(isEmphasized ? Color.black : PlaygroundTheme.text)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEmphasized ? PlaygroundTheme.nodeHighlight : PlaygroundTheme.nodeFill)
                    .overlay {
                        if isEmphasized {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PlaygroundTheme.accent.opacity(0.9), lineWidth: 2)
                                .scaleEffect(pulse ? 1.08 : 1.0)
                                .opacity(pulse ? 0.15 : 0.85)
                        }
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        focused ? PlaygroundTheme.accent : (highlighted ? PlaygroundTheme.accentSecondary : PlaygroundTheme.muted.opacity(0.35)),
                        lineWidth: focused ? 2.5 : 1.5
                    )
            )
            .shadow(
                color: isEmphasized
                    ? PlaygroundTheme.accentSecondary.opacity(0.55)
                    : Color.primary.opacity(0.12),
                radius: isEmphasized ? 12 : 4,
                y: 2
            )
            .scaleEffect(focused ? 1.12 : (highlighted ? 1.08 : 1.0))
            .animation(PlaygroundTheme.springBouncy, value: highlighted)
            .animation(PlaygroundTheme.springSnappy, value: focused)
            .animation(PlaygroundTheme.springSnappy, value: value)
            .onChange(of: isEmphasized) { _, isOn in
                guard isOn else {
                    pulse = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onAppear {
                if isEmphasized {
                    withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
    }
}

/// Node chip that highlights the matching source line on hover/click.
public struct InteractiveNodeChip: View {
    public let node: VizNode
    public var width: CGFloat = 56
    public var height: CGFloat = 44
    public var fallbackLine: Int? = nil

    @Environment(\.hoverSourceLine) private var hoverSourceLine
    @Environment(\.selectedSourceLine) private var selectedSourceLine
    @State private var isHovering = false

    public init(node: VizNode, width: CGFloat = 56, height: CGFloat = 44, fallbackLine: Int? = nil) {
        self.node = node
        self.width = width
        self.height = height
        self.fallbackLine = fallbackLine
    }

    private var resolvedLine: Int? {
        node.sourceLine ?? fallbackLine
    }

    private var isFocused: Bool {
        guard let line = resolvedLine else { return isHovering }
        return hoverSourceLine?.wrappedValue == line || selectedSourceLine?.wrappedValue == line || isHovering
    }

    public var body: some View {
        NodeChip(
            value: node.value,
            highlighted: node.highlighted,
            focused: isFocused,
            width: width,
            height: height
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                if let line = resolvedLine {
                    hoverSourceLine?.wrappedValue = line
                }
            } else if let line = resolvedLine, hoverSourceLine?.wrappedValue == line {
                hoverSourceLine?.wrappedValue = nil
            }
        }
        .onTapGesture {
            if let line = resolvedLine {
                selectedSourceLine?.wrappedValue = line
                hoverSourceLine?.wrappedValue = line
            }
        }
        .help(resolvedLine.map { "Jump to source line \($0)" } ?? "Run code to link this node to a source line")
        .accessibilityLabel(Text(node.value))
        .accessibilityHint(Text(resolvedLine.map { "Highlights source line \($0)" } ?? "No source mapping yet"))
    }
}

public struct EmptyVisualizerPlaceholder: View {
    public let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(PlaygroundTheme.accent)
                .symbolEffect(.pulse, options: .repeating)
            Text("Run, use built-in actions, or generate code to animate \(title)")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(PlaygroundTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct VisualizerChrome<Content: View>: View {
    public let caption: String
    @ViewBuilder public var content: () -> Content

    public init(caption: String, @ViewBuilder content: @escaping () -> Content) {
        self.caption = caption
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                AnimatedGridBackground()
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(caption)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(PlaygroundTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(PlaygroundTheme.panel)
                        .overlay(Capsule().stroke(PlaygroundTheme.muted.opacity(0.25), lineWidth: 1))
                )
                .animation(PlaygroundTheme.springSnappy, value: caption)
                .padding(.bottom, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlaygroundTheme.background)
    }
}

public struct AnimatedGridBackground: View {
    @State private var phase: CGFloat = 0

    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let drift = CGFloat(t.truncatingRemainder(dividingBy: 8)) / 8
                let spacing: CGFloat = 28
                var path = Path()
                stride(from: -spacing + drift * spacing, through: size.width + spacing, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: -spacing + (1 - drift) * spacing, through: size.height + spacing, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(PlaygroundTheme.muted.opacity(0.08)), lineWidth: 1)

                let glow = Gradient(colors: [
                    PlaygroundTheme.accent.opacity(0.12),
                    .clear,
                    PlaygroundTheme.accentSecondary.opacity(0.10)
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(glow, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
                )
            }
        }
        .background(PlaygroundTheme.background)
        .onAppear { phase = 1 }
    }
}

public extension AnyTransition {
    static var playgroundInsert: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.4).combined(with: .opacity).combined(with: .offset(y: -18)),
            removal: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(y: 16))
        )
    }

    static var playgroundSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.85)),
            removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.85))
        )
    }
}

public struct PointerOverlayView: View {
    public let label: String
    public let color: Color
    public var direction: Direction = .down

    public enum Direction {
        case up, down, left, right
    }

    public init(label: String, color: Color, direction: Direction = .down) {
        self.label = label
        self.color = color
        self.direction = direction
    }

    public var body: some View {
        Group {
            switch direction {
            case .down:
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 9.5, design: .rounded).weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                }
            case .up:
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.system(size: 9.5, design: .rounded).weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            case .left:
                HStack(spacing: 3) {
                    Text(label)
                        .font(.system(size: 9.5, design: .rounded).weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                }
            case .right:
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.system(size: 9.5, design: .rounded).weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
}

