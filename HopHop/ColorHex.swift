import SwiftUI

extension Color {
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0x888888
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}


extension Color {
    /// The colour as #rrggbb, the form the server stores.
    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#888888" }
        func part(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        return String(format: "#%02x%02x%02x", part(rgb.redComponent), part(rgb.greenComponent), part(rgb.blueComponent))
    }
}
