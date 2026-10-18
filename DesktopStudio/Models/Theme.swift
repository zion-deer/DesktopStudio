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
    var globals: ThemeGlobals
    var components: [DesktopComponent]

    func validate() throws {
        try ThemeValidation.requireText(name, field: "Theme name", limit: ThemeLimits.maxNameLength, allowNewlines: false)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ThemeCodingError.invalidTheme("A theme needs a name.")
        }
        if trimmedName.contains("/") || trimmedName.contains("\\") || trimmedName.contains("..") {
            throw ThemeCodingError.invalidTheme("A theme name cannot be a file path.")
        }
        try ThemeValidation.requireFinite(canvas.width, "Display width")
        try ThemeValidation.requireFinite(canvas.height, "Display height")
        if canvas.width < CanvasSettings.minimumWidth
            || canvas.height < CanvasSettings.minimumHeight
            || canvas.width > CanvasSettings.maximumWidth
            || canvas.height > CanvasSettings.maximumHeight
        {
            throw ThemeCodingError.invalidTheme("Display size must be between 320×240 and 7680×4320.")
        }
        try globals.validate()
        if components.count > ThemeLimits.maxComponents {
            throw ThemeCodingError.invalidTheme("A theme can contain at most \(ThemeLimits.maxComponents) components.")
        }

        var componentIDs = Set<UUID>()
        for component in components {
            if !componentIDs.insert(component.id).inserted {
                throw ThemeCodingError.invalidTheme("Two components share the same id \(component.id.uuidString).")
            }
            try ThemeValidation.requireText(component.name, field: "Component name", limit: ThemeLimits.maxNameLength, allowNewlines: false)
            if component.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ThemeCodingError.invalidTheme("A component needs a name.")
            }
            try component.frame.validate(named: component.name)
            try validate(component.settings, named: component.name)
            try validate(component.overrides, named: component.name)
        }
    }

    private func validate(_ settings: ComponentSettings, named name: String) throws {
        try ThemeValidation.requireText(settings.title, field: "\(name) title", limit: ThemeLimits.maxNameLength, allowNewlines: false)
        try ThemeValidation.requireText(settings.body, field: "\(name) body", limit: ThemeLimits.maxBodyLength, allowNewlines: true)
        try ThemeValidation.requireIdentifier(settings.symbolName, field: "\(name) symbol", limit: ThemeLimits.maxSymbolLength)
        try ThemeValidation.requireIdentifier(settings.bundleIdentifier, field: "\(name) bundle identifier", limit: ThemeLimits.maxBundleIdentifierLength)
        if settings.dockItems.count > ThemeLimits.maxDockItems {
            throw ThemeCodingError.invalidTheme("\(name) can contain at most \(ThemeLimits.maxDockItems) dock items.")
        }
        var dockItemIDs = Set<UUID>()
        for item in settings.dockItems {
            if !dockItemIDs.insert(item.id).inserted {
                throw ThemeCodingError.invalidTheme("\(name) has two dock items with the same id.")
            }
            try ThemeValidation.requireText(item.title, field: "\(name) dock item", limit: ThemeLimits.maxNameLength, allowNewlines: false)
            try ThemeValidation.requireIdentifier(item.symbolName, field: "\(name) dock symbol", limit: ThemeLimits.maxSymbolLength)
            try ThemeValidation.requireIdentifier(item.bundleIdentifier, field: "\(name) dock bundle identifier", limit: ThemeLimits.maxBundleIdentifierLength)
        }
        if settings.launcherFavorites.count > ThemeLimits.maxDockItems {
            throw ThemeCodingError.invalidTheme("\(name) can contain at most \(ThemeLimits.maxDockItems) launcher favorites.")
        }
        var favoriteIDs = Set<UUID>()
        for favorite in settings.launcherFavorites {
            if !favoriteIDs.insert(favorite.id).inserted {
                throw ThemeCodingError.invalidTheme("\(name) has two launcher favorites with the same id.")
            }
            try ThemeValidation.requireText(favorite.title, field: "\(name) launcher favorite", limit: ThemeLimits.maxNameLength, allowNewlines: false)
            try ThemeValidation.requireIdentifier(favorite.bundleIdentifier, field: "\(name) launcher bundle identifier", limit: ThemeLimits.maxBundleIdentifierLength)
            try ThemeValidation.requireText(favorite.groupName, field: "\(name) launcher group", limit: ThemeLimits.maxNameLength, allowNewlines: false)
        }
        try ThemeValidation.requireRange(settings.launcherSpacing, 0...ThemeLimits.maxSpacing, "\(name) launcher spacing")
        try LauncherShortcut.validate(key: settings.launcherShortcutKey, modifiers: settings.launcherShortcutModifiers, field: name)
        try ThemeValidation.requireRange(settings.dockIconSize, DockLayout.iconSizeRange, "\(name) icon size")
        try ThemeValidation.requireRange(settings.dockSpacing, DockLayout.spacingRange, "\(name) icon spacing")
        try ThemeValidation.requireRange(settings.dockPadding, DockLayout.paddingRange, "\(name) dock padding")
    }

    private func validate(_ overrides: AppearanceOverrides, named name: String) throws {
        if let opacity = overrides.opacity {
            try ThemeValidation.requireUnit(opacity, "\(name) opacity")
        }
        if let cornerRadius = overrides.cornerRadius {
            try ThemeValidation.requireRange(cornerRadius, 0...ComponentAppearance.maximumCornerRadius, "\(name) corner radius")
        }
        if let fontSize = overrides.fontSize {
            try ThemeValidation.requireRange(fontSize, ComponentAppearance.minimumFontSize...ComponentAppearance.maximumFontSize, "\(name) font size")
        }
        if let borderWidth = overrides.borderWidth {
            try ThemeValidation.requireRange(borderWidth, 0...ComponentAppearance.maximumBorderWidth, "\(name) border width")
        }
    }
}

struct ThemeDocument: Codable, Hashable {
    /// Schema 2 adds theme globals and per-component overrides. Schema 1 documents are migrated on open.
    static let currentSchemaVersion = 2
    static let minimumReadableSchemaVersion = 1

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
