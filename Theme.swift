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
/// Light is cool paper white, dark is deep navy. The same tokens as the web app's global.css.
enum HH {
    static let bg = Color(light: "#F8FAFC", dark: "#0B1220")
    static let surface = Color(light: "#FFFFFF", dark: "#111A2E")
    static let sunken = Color(light: "#F1F5F9", dark: "#0D1526")
    static let border = Color(light: "#E2E8F0", dark: "#1E2B45")
    static let borderStrong = Color(light: "#CBD5E1", dark: "#2B3A59")
    static let ink = Color(light: "#0F172A", dark: "#E2E8F0")
    static let muted = Color(light: "#475569", dark: "#94A3B8")

    static let primary = Color(light: "#0369A1", dark: "#38BDF8")
    static let onPrimary = Color(light: "#FFFFFF", dark: "#082F49")
    static let primarySoft = Color(light: "#E0F2FE", dark: "#0C2A40")
    static let primaryInk = Color(light: "#075985", dark: "#7DD3FC")

    static let danger = Color(light: "#B91C1C", dark: "#F87171")
    static let dangerSoft = Color(light: "#FEE2E2", dark: "#3B1418")
    static let warnSoft = Color(light: "#FEF3C7", dark: "#3A2E0F")
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
