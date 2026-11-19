import AppKit
import SwiftUI

extension Color {
    /// A colour that follows the window's light or dark appearance.
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}

/// HopHop look: minimal and professional. Flat surfaces, thin borders, one calm blue accent.
/// Light is cool paper white, dark is graphite with an indigo accent. The same tokens as the web app's global.css.
enum HH {
    static let bg = Color(light: "#E6EBF1", dark: "#121214")
    static let surface = Color(light: "#F3F6F9", dark: "#1b1b1f")
    static let sunken = Color(light: "#DAE1EA", dark: "#151518")
    static let border = Color(light: "#C8D1DD", dark: "#2a2a30")
    static let borderStrong = Color(light: "#A3B0C1", dark: "#3a3a42")
    static let ink = Color(light: "#0F172A", dark: "#ececf1")
    static let muted = Color(light: "#475569", dark: "#a1a1ad")

    static let primary = Color(light: "#0369A1", dark: "#818cf8")
    static let onPrimary = Color(light: "#FFFFFF", dark: "#1e1b4b")
    static let primarySoft = Color(light: "#CFE4F3", dark: "#272650")
    static let primaryInk = Color(light: "#075985", dark: "#a5b4fc")

    static let danger = Color(light: "#B91C1C", dark: "#F87171")
    static let dangerSoft = Color(light: "#F3D3D3", dark: "#3b1a1e")
    static let warnSoft = Color(light: "#F2E3B5", dark: "#3A2E0F")
    static let warnInk = Color(light: "#92400E", dark: "#FCD34D")

    /// Interface text.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    /// Page and dialog titles.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    /// Tag keys and other code-like text.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Makes the bundled font available. Without it the system font stands in.
    static func registerFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
