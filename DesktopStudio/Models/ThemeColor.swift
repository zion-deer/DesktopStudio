import Foundation

/// An sRGB color stored with themes. JSON uses a `#RRGGBB` hex string plus a separate opacity.
struct ThemeColor: Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = Self.clampUnit(red)
        self.green = Self.clampUnit(green)
        self.blue = Self.clampUnit(blue)
        self.opacity = Self.clampUnit(opacity)
    }

    init(hex: String, opacity: Double = 1) {
        if let parsed = Self.parse(hex) {
            self.init(red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: opacity)
        } else {
            assertionFailure("Invalid color hex \(hex)")
            self.init(red: 0, green: 0, blue: 0, opacity: opacity)
        }
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Self.channelByte(red),
            Self.channelByte(green),
            Self.channelByte(blue)
        )
    }

    static func normalize(_ raw: String) -> String? {
        guard let parsed = parse(raw) else { return nil }
        return ThemeColor(red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: 1).hex
    }

    static func parse(_ raw: String) -> (red: Double, green: Double, blue: Double)? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        if value.count == 3, value.allSatisfy(\.isHexDigit) {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6, value.allSatisfy(\.isHexDigit) else { return nil }
        let characters = Array(value)
        guard
            let red = channel(characters[0...1]),
            let green = channel(characters[2...3]),
            let blue = channel(characters[4...5])
        else {
            return nil
        }
        return (red, green, blue)
    }

    private static func channel(_ pair: ArraySlice<Character>) -> Double? {
        guard let number = Int(String(pair), radix: 16) else { return nil }
        return Double(number) / 255
    }

    private static func channelByte(_ value: Double) -> Int {
        Int((clampUnit(value) * 255).rounded())
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

extension ThemeColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case hex
        case opacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hex = try container.decode(String.self, forKey: .hex)
        let opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        guard opacity.isFinite, (0...1).contains(opacity) else {
            throw DecodingError.dataCorruptedError(
                forKey: .opacity,
                in: container,
                debugDescription: "Color opacity must be from 0 to 1."
            )
        }
        guard let parsed = Self.parse(hex) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hex,
                in: container,
                debugDescription: "Expected a hex color such as #1C2436."
            )
        }
        self.init(red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hex, forKey: .hex)
        try container.encode(opacity, forKey: .opacity)
    }
}
