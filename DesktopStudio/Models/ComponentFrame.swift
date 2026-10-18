import Foundation

struct ComponentFrame: Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var zIndex: Int

    static let minimumLength: Double = 48

    func clamped(to canvas: CanvasSettings) -> ComponentFrame {
        var frame = self
        let maxWidth = max(canvas.width, Self.minimumLength)
        let maxHeight = max(canvas.height, Self.minimumLength)
        frame.width = min(max(frame.width, Self.minimumLength), maxWidth)
        frame.height = min(max(frame.height, Self.minimumLength), maxHeight)
        let maxX = max(canvas.width - frame.width, 0)
        let maxY = max(canvas.height - frame.height, 0)
        frame.x = min(max(frame.x, 0), maxX)
        frame.y = min(max(frame.y, 0), maxY)
        return frame
    }

    func validate(named name: String) throws {
        try ThemeValidation.requireFinite(x, "\(name) x")
        try ThemeValidation.requireFinite(y, "\(name) y")
        try ThemeValidation.requireFinite(width, "\(name) width")
        try ThemeValidation.requireFinite(height, "\(name) height")
        guard abs(x) <= ThemeLimits.maxAbsolutePosition, abs(y) <= ThemeLimits.maxAbsolutePosition else {
            throw ThemeCodingError.invalidTheme("\(name) is too far from the display.")
        }
        guard width > 0, height > 0 else {
            throw ThemeCodingError.invalidTheme("\(name) has a width or height that is not positive.")
        }
        guard width <= ThemeLimits.maxComponentLength, height <= ThemeLimits.maxComponentLength else {
            throw ThemeCodingError.invalidTheme("\(name) is larger than \(Int(ThemeLimits.maxComponentLength)) points.")
        }
        guard abs(zIndex) <= ThemeLimits.maxZIndex else {
            throw ThemeCodingError.invalidTheme("\(name) has a layer index that is out of range.")
        }
    }
}

extension ComponentFrame: Codable {
    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
        case zIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try Self.finite(container, .x, name: "x")
        y = try Self.finite(container, .y, name: "y")
        width = try Self.finite(container, .width, name: "width")
        height = try Self.finite(container, .height, name: "height")
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        try validate(named: "Component")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(zIndex, forKey: .zIndex)
    }

    private static func finite(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        name: String
    ) throws -> Double {
        let value = try container.decode(Double.self, forKey: key)
        guard value.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "\(name) must be a finite number.")
        }
        return value
    }
}
