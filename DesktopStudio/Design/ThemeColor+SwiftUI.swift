import AppKit
import SwiftUI

extension ThemeColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        let nsColor = NSColor(color)
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
        } else {
            self.init(red: 0, green: 0, blue: 0, opacity: Double(converted.alphaComponent))
        }
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
