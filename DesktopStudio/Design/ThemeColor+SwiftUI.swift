import AppKit
import SwiftUI

extension ThemeColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor.usingColorSpace(.deviceRGB) else {
            self.init(red: 0, green: 0, blue: 0, opacity: Double(nsColor.alphaComponent))
            return
        }
        self.init(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            opacity: Double(rgb.alphaComponent)
        )
    }
}

extension StudioFontDesign {
    var fontDesign: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

extension StudioFontWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
