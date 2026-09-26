import SwiftUI
import CoreText

/// Colors, type and spacing from `assets/brand/tokens.json` (v0.2.0-refined), as static values
/// so views do not parse JSON at runtime. If tokens.json changes, update the hex values here.
enum Brand {
    // MARK: Audience theme (light: the half facing them)
    enum Audience {
        static let background = Color(hex: 0xF1F2F4)   // Paper
        static let surface    = Color(hex: 0xFFFFFF)   // Card
        static let text       = Color(hex: 0x111418)   // Ink
        static let muted      = Color(hex: 0x5F6875)   // Graphite
        static let accent     = Color(hex: 0x0E6B5E)   // Verdigris
    }

    // MARK: Presenter theme (dark: the half facing you)
    enum Presenter {
        static let background = Color(hex: 0x111418)   // Ink
        static let surface    = Color(hex: 0x1A1E24)   // Slate
        static let text       = Color(hex: 0xF1F2F4)   // Paper
        static let muted      = Color(hex: 0x9AA3AE)   // Ash
        /// Verdigris Light. Put Ink text on accent fills in this theme, not white.
        static let accent     = Color(hex: 0x3E9C85)
    }

    enum Crease {
        static let light = Color(hex: 0x111418, opacity: 0.12)
        static let dark  = Color(hex: 0xF1F2F4, opacity: 0.14)
    }

    /// Shortcuts by token name.
    static let paper     = Audience.background
    static let card      = Audience.surface
    static let ink       = Audience.text
    static let graphite  = Audience.muted
    static let verdigris = Audience.accent
    static let slate     = Presenter.surface
    static let ash       = Presenter.muted
    static let verdigrisLight = Presenter.accent

    // MARK: Type. Display face is Instrument Serif (bundled), text face is SF Pro (system).
    enum Font {
        static let displayFamily = "Instrument Serif"
        static let displayRegular = "InstrumentSerif-Regular"
        static let displayItalic = "InstrumentSerif-Italic"

        static func display(_ size: CGFloat) -> SwiftUI.Font {
            registerIfNeeded()
            return .custom(displayRegular, size: size)
        }
        static func displayItalic(_ size: CGFloat) -> SwiftUI.Font {
            registerIfNeeded()
            return .custom(displayItalic, size: size)
        }
        static func text(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }

        // tokens.json type.scale_pt
        static var slideTitle: SwiftUI.Font { display(48) }
        static var slideStatement: SwiftUI.Font { displayItalic(40) }
        static var slideHeading: SwiftUI.Font { display(28) }
        static var slideBody: SwiftUI.Font { text(22) }
        static var presenterNotes: SwiftUI.Font { text(17) }
        static var uiLabel: SwiftUI.Font { text(13, .medium) }
        static var caption: SwiftUI.Font { text(12) }

        /// Registers the bundled TTFs once. Runtime registration means no Info.plist key is needed
        /// and xcodegen's generated plist stays untouched.
        nonisolated(unsafe) private static var registered = false
        static func registerIfNeeded() {
            guard !registered else { return }
            registered = true
            for name in [displayRegular, displayItalic] {
                guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    // MARK: Spacing and radii (tokens.json space / radius)
    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 24
        static let s6: CGFloat = 32
        static let s7: CGFloat = 48
        static let s8: CGFloat = 64
        static let s9: CGFloat = 96
        static let slideMargin: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 14
        static let sheet: CGFloat = 22
    }

    /// The rendered slide PNGs are 2400x1260, a 40:21 canvas.
    static let slideAspect: CGFloat = 2400.0 / 1260.0
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
