import Foundation

/// Per-component style fields that replace the theme's resolved style.
/// Nil means "inherit". This type is data only and does not render anything.
struct AppearanceOverrides: Codable, Hashable {
    var background: ThemeColor?
    var foreground: ThemeColor?
    var accent: ThemeColor?
    var cornerRadius: Double?
    var opacity: Double?
    var fontSize: Double?
    var fontDesign: StudioFontDesign?
    var fontWeight: StudioFontWeight?
    var shadowEnabled: Bool?
    var borderWidth: Double?
    var borderColor: ThemeColor?

    var isEmpty: Bool {
        background == nil
            && foreground == nil
            && accent == nil
            && cornerRadius == nil
            && opacity == nil
            && fontSize == nil
            && fontDesign == nil
            && fontWeight == nil
            && shadowEnabled == nil
            && borderWidth == nil
            && borderColor == nil
    }

    init(
        background: ThemeColor? = nil,
        foreground: ThemeColor? = nil,
        accent: ThemeColor? = nil,
        cornerRadius: Double? = nil,
        opacity: Double? = nil,
        fontSize: Double? = nil,
        fontDesign: StudioFontDesign? = nil,
        fontWeight: StudioFontWeight? = nil,
        shadowEnabled: Bool? = nil,
        borderWidth: Double? = nil,
        borderColor: ThemeColor? = nil
    ) {
        self.background = background
        self.foreground = foreground
        self.accent = accent
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
        self.shadowEnabled = shadowEnabled
        self.borderWidth = borderWidth
        self.borderColor = borderColor
    }

    private enum CodingKeys: String, CodingKey {
        case background
        case foreground
        case accent
        case cornerRadius
        case opacity
        case fontSize
        case fontDesign
        case fontWeight
        case shadowEnabled
        case borderWidth
        case borderColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decodeIfPresent(ThemeColor.self, forKey: .background)
        foreground = try container.decodeIfPresent(ThemeColor.self, forKey: .foreground)
        accent = try container.decodeIfPresent(ThemeColor.self, forKey: .accent)
        cornerRadius = try Self.finite(container, .cornerRadius, name: "cornerRadius")
        opacity = try Self.unit(container, .opacity, name: "opacity")
        fontSize = try Self.finite(container, .fontSize, name: "fontSize")
        fontDesign = try container.decodeIfPresent(StudioFontDesign.self, forKey: .fontDesign)
        fontWeight = try container.decodeIfPresent(StudioFontWeight.self, forKey: .fontWeight)
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled)
        borderWidth = try Self.finite(container, .borderWidth, name: "borderWidth")
        borderColor = try container.decodeIfPresent(ThemeColor.self, forKey: .borderColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encodeIfPresent(foreground, forKey: .foreground)
        try container.encodeIfPresent(accent, forKey: .accent)
        try container.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
        try container.encodeIfPresent(opacity, forKey: .opacity)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(fontDesign, forKey: .fontDesign)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(shadowEnabled, forKey: .shadowEnabled)
        try container.encodeIfPresent(borderWidth, forKey: .borderWidth)
        try container.encodeIfPresent(borderColor, forKey: .borderColor)
    }

    private static func finite(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        name: String
    ) throws -> Double? {
        guard let value = try container.decodeIfPresent(Double.self, forKey: key) else { return nil }
        guard value.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "\(name) must be a finite number.")
        }
        return value
    }

    private static func unit(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        name: String
    ) throws -> Double? {
        guard let value = try finite(container, key, name: name) else { return nil }
        guard (0...1).contains(value) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "\(name) must be from 0 to 1.")
        }
        return value
    }
}
