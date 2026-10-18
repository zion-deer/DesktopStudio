import Foundation

enum StudioFontDesign: String, Codable, Hashable, CaseIterable, Identifiable {
    case standard
    case rounded
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }
}

enum StudioFontWeight: String, Codable, Hashable, CaseIterable, Identifiable {
    case regular
    case medium
    case semibold
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        }
    }
}

struct ComponentAppearance: Codable, Hashable {
    var background: ThemeColor
    var foreground: ThemeColor
    var accent: ThemeColor
    var cornerRadius: Double
    var opacity: Double
    var fontSize: Double
    var fontDesign: StudioFontDesign
    var fontWeight: StudioFontWeight
    var shadowEnabled: Bool
    var borderWidth: Double
    var borderColor: ThemeColor

    static let minimumFontSize: Double = 8
    static let maximumFontSize: Double = 160
    static let maximumCornerRadius: Double = 80
    static let maximumBorderWidth: Double = 16

    func sanitized() -> ComponentAppearance {
        var appearance = self
        appearance.opacity = min(max(appearance.opacity, 0), 1)
        appearance.fontSize = min(max(appearance.fontSize, Self.minimumFontSize), Self.maximumFontSize)
        appearance.cornerRadius = min(max(appearance.cornerRadius, 0), Self.maximumCornerRadius)
        appearance.borderWidth = min(max(appearance.borderWidth, 0), Self.maximumBorderWidth)
        return appearance
    }

    static func standard(for type: ComponentType) -> ComponentAppearance {
        switch type {
        case .clock:
            return ComponentAppearance(
                background: ThemeColor(hex: "#121826", opacity: 0.875),
                foreground: ThemeColor(hex: "#F4F7FB"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 24,
                opacity: 1,
                fontSize: 52,
                fontDesign: .rounded,
                fontWeight: .semibold,
                shadowEnabled: true,
                borderWidth: 1,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.125)
            )
        case .text:
            return ComponentAppearance(
                background: ThemeColor(hex: "#000000", opacity: 0),
                foreground: ThemeColor(hex: "#F4F7FB"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 0,
                opacity: 1,
                fontSize: 42,
                fontDesign: .standard,
                fontWeight: .semibold,
                shadowEnabled: false,
                borderWidth: 0,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0)
            )
        case .appShortcut:
            return ComponentAppearance(
                background: ThemeColor(hex: "#161C2E", opacity: 0.875),
                foreground: ThemeColor(hex: "#F4F7FB"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 18,
                opacity: 1,
                fontSize: 16,
                fontDesign: .standard,
                fontWeight: .semibold,
                shadowEnabled: true,
                borderWidth: 1,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.125)
            )
        case .dock:
            return ComponentAppearance(
                background: ThemeColor(hex: "#0C101C", opacity: 0.75),
                foreground: ThemeColor(hex: "#F4F7FB"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 26,
                opacity: 1,
                fontSize: 20,
                fontDesign: .standard,
                fontWeight: .medium,
                shadowEnabled: true,
                borderWidth: 1,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.125)
            )
        case .notes:
            return ComponentAppearance(
                background: ThemeColor(hex: "#1A2236"),
                foreground: ThemeColor(hex: "#E7ECF5"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 22,
                opacity: 1,
                fontSize: 22,
                fontDesign: .serif,
                fontWeight: .medium,
                shadowEnabled: true,
                borderWidth: 1,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.125)
            )
        case .launcher:
            return ComponentAppearance(
                background: ThemeColor(hex: "#1C1C1E", opacity: 0.94),
                foreground: ThemeColor(hex: "#F5F5F7"),
                accent: ThemeColor(hex: "#9DB7FF"),
                cornerRadius: 16,
                opacity: 1,
                fontSize: 15,
                fontDesign: .standard,
                fontWeight: .regular,
                shadowEnabled: true,
                borderWidth: 1,
                borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.12)
            )
        }
    }
}
