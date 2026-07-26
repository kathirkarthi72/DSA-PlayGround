import SwiftUI
import AppKit

/// Xcode-like chrome + syntax palette that follows system light/dark appearance.
enum EditorChrome {
    // Surfaces
    static let editorBackground = Color(nsColor: Syntax.background)
    static let tabBarBackground = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.165, green: 0.165, blue: 0.184, alpha: 1)
            : NSColor(calibratedRed: 0.93, green: 0.935, blue: 0.945, alpha: 1)
    })
    static let breadcrumbBackground = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.145, green: 0.145, blue: 0.165, alpha: 1)
            : NSColor(calibratedRed: 0.96, green: 0.965, blue: 0.975, alpha: 1)
    })
    static let activeTabBackground = Color(nsColor: Syntax.background)
    static let separator = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedWhite: 1, alpha: 0.08)
            : NSColor(calibratedWhite: 0, alpha: 0.10)
    })
    static let mutedText = Color(nsColor: NSColor(name: nil) { appearance in
        Self.isDark(appearance)
            ? NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.66, alpha: 1)
            : NSColor(calibratedRed: 0.45, green: 0.47, blue: 0.52, alpha: 1)
    })
    static let primaryText = Color(nsColor: Syntax.foreground)

    // Swift icon
    static let swiftOrange = Color(red: 0.95, green: 0.42, blue: 0.22)

    enum Syntax {
        /// Static colors for text attributes / AppKit views.
        /// Dynamic NSColors often bake wrong in NSTextStorage and can make
        /// dark text land on a dark editor background (invisible Swift code).
        struct Palette {
            let background: NSColor
            let foreground: NSColor
            let keyword: NSColor
            let type: NSColor
            let string: NSColor
            let comment: NSColor
            let number: NSColor
            let attribute: NSColor
            let caret: NSColor
            let selection: NSColor
            let focusedLineHighlight: NSColor
            let lineHighlight: NSColor
            let gutterBackground: NSColor
            let gutterText: NSColor
            let gutterSeparator: NSColor
            let foldMarker: NSColor
        }

        static func palette(for appearance: NSAppearance) -> Palette {
            palette(dark: EditorChrome.isDark(appearance))
        }

        static func palette(for colorScheme: ColorScheme) -> Palette {
            palette(dark: colorScheme == .dark)
        }

        private static func palette(dark: Bool) -> Palette {
            Palette(
                background: dark
                    ? NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.137, alpha: 1)
                    : NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                foreground: dark
                    ? NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.94, alpha: 1)
                    : NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1),
                keyword: dark
                    ? NSColor(calibratedRed: 0.42, green: 0.82, blue: 0.86, alpha: 1)
                    : NSColor(calibratedRed: 0.61, green: 0.15, blue: 0.57, alpha: 1),
                type: dark
                    ? NSColor(calibratedRed: 0.93, green: 0.72, blue: 0.53, alpha: 1)
                    : NSColor(calibratedRed: 0.30, green: 0.37, blue: 0.65, alpha: 1),
                string: dark
                    ? NSColor(calibratedRed: 0.98, green: 0.48, blue: 0.45, alpha: 1)
                    : NSColor(calibratedRed: 0.77, green: 0.10, blue: 0.09, alpha: 1),
                comment: dark
                    ? NSColor(calibratedRed: 0.48, green: 0.52, blue: 0.58, alpha: 1)
                    : NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.53, alpha: 1),
                number: dark
                    ? NSColor(calibratedRed: 0.78, green: 0.58, blue: 0.96, alpha: 1)
                    : NSColor(calibratedRed: 0.11, green: 0.00, blue: 0.81, alpha: 1),
                attribute: dark
                    ? NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.40, alpha: 1)
                    : NSColor(calibratedRed: 0.70, green: 0.35, blue: 0.00, alpha: 1),
                caret: dark
                    ? NSColor(calibratedRed: 0.45, green: 0.78, blue: 1.0, alpha: 1)
                    : NSColor(calibratedRed: 0.10, green: 0.40, blue: 0.90, alpha: 1),
                selection: dark
                    ? NSColor(calibratedRed: 0.25, green: 0.40, blue: 0.62, alpha: 0.55)
                    : NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.98, alpha: 0.85),
                focusedLineHighlight: dark
                    ? NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.25, alpha: 1.0)
                    : NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1.0),
                lineHighlight: NSColor(calibratedRed: 0.95, green: 0.62, blue: 0.28, alpha: 0.22),
                gutterBackground: dark
                    ? NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.137, alpha: 1)
                    : NSColor(calibratedRed: 0.97, green: 0.975, blue: 0.985, alpha: 1),
                gutterText: dark
                    ? NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.52, alpha: 1)
                    : NSColor(calibratedRed: 0.55, green: 0.57, blue: 0.60, alpha: 1),
                gutterSeparator: dark
                    ? NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.26, alpha: 1)
                    : NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.89, alpha: 1),
                foldMarker: dark
                    ? NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.64, alpha: 1)
                    : NSColor(calibratedRed: 0.50, green: 0.53, blue: 0.58, alpha: 1)
            )
        }

        static let background = NSColor(name: nil) { appearance in
            palette(for: appearance).background
        }

        static let foreground = NSColor(name: nil) { appearance in
            palette(for: appearance).foreground
        }

        static let keyword = NSColor(name: nil) { appearance in
            palette(for: appearance).keyword
        }

        static let type = NSColor(name: nil) { appearance in
            palette(for: appearance).type
        }

        static let string = NSColor(name: nil) { appearance in
            palette(for: appearance).string
        }

        static let comment = NSColor(name: nil) { appearance in
            palette(for: appearance).comment
        }

        static let number = NSColor(name: nil) { appearance in
            palette(for: appearance).number
        }

        static let attribute = NSColor(name: nil) { appearance in
            palette(for: appearance).attribute
        }

        static let caret = NSColor(name: nil) { appearance in
            palette(for: appearance).caret
        }

        static let selection = NSColor(name: nil) { appearance in
            palette(for: appearance).selection
        }

        /// Subtle caret / focused line (IDE-style).
        static let focusedLineHighlight = NSColor(name: nil) { appearance in
            palette(for: appearance).focusedLineHighlight
        }

        /// Stronger highlight for canvas / diagnostic line.
        static let lineHighlight = NSColor(calibratedRed: 0.95, green: 0.62, blue: 0.28, alpha: 0.22)

        /// Soft highlight for previous / next lines around a canvas selection.
        static let contextLineHighlight = NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.95, alpha: 0.12)

        static let gutterBackground = NSColor(name: nil) { appearance in
            palette(for: appearance).gutterBackground
        }

        static let gutterText = NSColor(name: nil) { appearance in
            palette(for: appearance).gutterText
        }

        static let gutterSeparator = NSColor(name: nil) { appearance in
            palette(for: appearance).gutterSeparator
        }

        static let foldMarker = NSColor(name: nil) { appearance in
            palette(for: appearance).foldMarker
        }
    }

    static func isDark(_ appearance: NSAppearance = NSApp.effectiveAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func nsAppearance(for colorScheme: ColorScheme) -> NSAppearance {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
            ?? NSApp.effectiveAppearance
    }
}

struct SwiftFileIcon: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.55, blue: 0.28),
                            Color(red: 0.92, green: 0.28, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "swift")
                .font(.system(size: size * 0.62, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
