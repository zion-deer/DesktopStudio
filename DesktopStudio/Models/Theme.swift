import Foundation

enum WallpaperStyle: String, Hashable, CaseIterable, Identifiable {
    case solid
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .gradient: "Gradient"
        }
    }
}

extension WallpaperStyle: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = WallpaperStyle(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown wallpaper style “\(rawValue)”. Expected solid or gradient."
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CanvasSettings: Codable, Hashable {
    var width: Double
    var height: Double
    var style: WallpaperStyle
    var background: ThemeColor
    var gradientEnd: ThemeColor

    static let minimumWidth: Double = 320
    static let minimumHeight: Double = 240
    static let maximumWidth: Double = 7680
    static let maximumHeight: Double = 4320

    func sanitized() -> CanvasSettings {
        var canvas = self
        canvas.width = min(max(canvas.width, Self.minimumWidth), Self.maximumWidth)
        canvas.height = min(max(canvas.height, Self.minimumHeight), Self.maximumHeight)
        return canvas
    }
}

struct Theme: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var canvas: CanvasSettings
    var components: [DesktopComponent]

    func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ThemeCodingError.invalidTheme("A theme needs a name.")
        }
        if canvas.width < CanvasSettings.minimumWidth
            || canvas.height < CanvasSettings.minimumHeight
            || canvas.width > CanvasSettings.maximumWidth
            || canvas.height > CanvasSettings.maximumHeight
        {
            throw ThemeCodingError.invalidTheme("Display size must be between 320×240 and 7680×4320.")
        }

        var componentIDs = Set<UUID>()
        for component in components {
            if !componentIDs.insert(component.id).inserted {
                throw ThemeCodingError.invalidTheme("Two components share the same id \(component.id.uuidString).")
            }
            if component.frame.width <= 0 || component.frame.height <= 0 {
                throw ThemeCodingError.invalidTheme("\(component.name) has a width or height that is not positive.")
            }
            var dockItemIDs = Set<UUID>()
            for item in component.settings.dockItems {
                if !dockItemIDs.insert(item.id).inserted {
                    throw ThemeCodingError.invalidTheme("\(component.name) has two dock items with the same id.")
                }
            }
        }
    }
}

struct ThemeDocument: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var theme: Theme

    init(theme: Theme) {
        self.schemaVersion = Self.currentSchemaVersion
        self.theme = theme
    }
}

enum ThemeCodingError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidTheme(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Theme schema version \(version) is not supported."
        case .invalidTheme(let reason):
            return reason
        }
    }
}
