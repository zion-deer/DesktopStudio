import Foundation

struct PreparedThemeDocument {
    var json: Data
    var warnings: [String]
}

/// Moves older theme documents to the current schema and drops unknown component types.
/// The result is plain JSON. It does not depend on SwiftUI.
enum ThemeMigration {
    static func prepare(_ object: [String: Any]) throws -> PreparedThemeDocument {
        let version = try schemaVersion(in: object)
        guard version >= ThemeDocument.minimumReadableSchemaVersion else {
            throw ThemeCodingError.unsupportedSchema(version)
        }
        guard version <= ThemeDocument.currentSchemaVersion else {
            throw ThemeCodingError.unsupportedSchema(version)
        }
        try requireKeys(object, allowed: ["schemaVersion", "theme"], context: "document")
        guard var theme = object["theme"] as? [String: Any] else {
            throw ThemeCodingError.invalidTheme("The document is missing a theme object.")
        }

        let warnings: [String]
        if version == 1 {
            warnings = try migrateVersion1(&theme)
        } else {
            warnings = try normalizeVersion2(&theme)
        }

        let document: [String: Any] = [
            "schemaVersion": ThemeDocument.currentSchemaVersion,
            "theme": theme
        ]
        let json = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
        return PreparedThemeDocument(json: json, warnings: warnings)
    }

    private static func migrateVersion1(_ theme: inout [String: Any]) throws -> [String] {
        try requireKeys(
            theme,
            allowed: ["id", "name", "createdAt", "updatedAt", "canvas", "components"],
            context: "schema 1 theme"
        )
        guard let canvas = theme["canvas"] as? [String: Any] else {
            throw ThemeCodingError.invalidTheme("The theme is missing a canvas.")
        }
        try requireKeys(canvas, allowed: ["width", "height", "style", "background", "gradientEnd"], context: "canvas")
        try scanColor(canvas["background"], name: "canvas background")
        try scanColor(canvas["gradientEnd"], name: "canvas gradient")
        let canvasSettings = try decode(CanvasSettings.self, from: canvas, name: "canvas")
        let globals = ThemeGlobals.importedLegacy(from: canvasSettings)
        theme["globals"] = try jsonObject(globals)
        return try normalizeComponents(&theme, appearanceKey: "appearance")
    }

    private static func normalizeVersion2(_ theme: inout [String: Any]) throws -> [String] {
        try requireKeys(
            theme,
            allowed: ["id", "name", "createdAt", "updatedAt", "canvas", "globals", "components"],
            context: "theme"
        )
        guard let globals = theme["globals"] else {
            throw ThemeCodingError.invalidTheme("The theme is missing globals.")
        }
        try scanKnownContainers(in: theme)
        _ = globals
        return try normalizeComponents(&theme, appearanceKey: nil)
    }

    private static func normalizeComponents(_ theme: inout [String: Any], appearanceKey: String?) throws -> [String] {
        guard let rawComponents = theme["components"] as? [Any] else {
            throw ThemeCodingError.invalidTheme("The theme is missing a components array.")
        }
        var kept: [[String: Any]] = []
        var warnings: [String] = []
        for (index, raw) in rawComponents.enumerated() {
            guard var component = raw as? [String: Any] else {
                throw ThemeCodingError.invalidTheme("Component \(index + 1) is not an object.")
            }
            guard let typeName = component["type"] as? String else {
                throw ThemeCodingError.invalidTheme("Component \(index + 1) is missing a type.")
            }
            guard ComponentType(rawValue: typeName) != nil else {
                let label = (component["name"] as? String).map { "“\($0)”" } ?? "component \(index + 1)"
                warnings.append("Skipped \(label) because “\(typeName)” is not a known component type.")
                continue
            }
            if let appearanceKey {
                try requireKeys(
                    component,
                    allowed: ["id", "type", "name", "frame", "appearance", "settings"],
                    context: "schema 1 component"
                )
                guard let appearance = component.removeValue(forKey: appearanceKey) as? [String: Any] else {
                    throw ThemeCodingError.invalidTheme("\(typeName) is missing appearance.")
                }
                try requireKeys(appearance, allowed: overrideKeys, context: "appearance")
                try scanOverrideColors(appearance)
                component["overrides"] = appearance
            } else {
                try requireKeys(
                    component,
                    allowed: ["id", "type", "name", "frame", "overrides", "settings"],
                    context: "component"
                )
                if component["overrides"] == nil {
                    component["overrides"] = [String: Any]()
                }
                if let overrides = component["overrides"] as? [String: Any] {
                    try requireKeys(overrides, allowed: overrideKeys, context: "overrides")
                    try scanOverrideColors(overrides)
                } else {
                    throw ThemeCodingError.invalidTheme("\(typeName) overrides must be an object.")
                }
            }
            try scanComponentDetails(component)
            kept.append(component)
        }
        theme["components"] = kept
        return warnings
    }

    private static func scanKnownContainers(in theme: [String: Any]) throws {
        if let canvas = theme["canvas"] as? [String: Any] {
            try requireKeys(canvas, allowed: ["width", "height", "style", "background", "gradientEnd"], context: "canvas")
            try scanColor(canvas["background"], name: "canvas background")
            try scanColor(canvas["gradientEnd"], name: "canvas gradient")
        }
        if let globals = theme["globals"] as? [String: Any] {
            try requireKeys(
                globals,
                allowed: ["accent", "background", "typography", "spacing", "cornerRadius", "componentStyles"],
                context: "globals"
            )
            try scanColor(globals["accent"], name: "accent")
            try scanColor(globals["background"], name: "background")
            if let typography = globals["typography"] as? [String: Any] {
                try requireKeys(typography, allowed: ["fontDesign", "fontWeight", "baseFontSize"], context: "typography")
            }
            if let styles = globals["componentStyles"] as? [String: Any] {
                try requireKeys(styles, allowed: ["clock", "text", "appShortcut", "dock", "notes", "launcher"], context: "component styles")
                for (name, value) in styles {
                    guard let style = value as? [String: Any] else {
                        throw ThemeCodingError.invalidTheme("The \(name) style must be an object.")
                    }
                    try requireKeys(style, allowed: styleKeys, context: "\(name) style")
                    try scanOverrideColors(style)
                }
            }
        }
    }

    private static func scanComponentDetails(_ component: [String: Any]) throws {
        if let frame = component["frame"] as? [String: Any] {
            try requireKeys(frame, allowed: ["x", "y", "width", "height", "zIndex"], context: "frame")
        }
        if let settings = component["settings"] as? [String: Any] {
            try requireKeys(
                settings,
                allowed: ["title", "body", "symbolName", "bundleIdentifier", "timeFormat", "showsDate", "showsSeconds", "dockItems", "dockIconSize", "dockSpacing", "dockPadding", "dockAlignment", "dockEdge", "launchAtLogin", "launcherFavorites", "launcherSpacing", "launcherPlacement", "launcherShortcutKey", "launcherShortcutModifiers"],
                context: "settings"
            )
            if let items = settings["dockItems"] as? [Any] {
                for item in items {
                    guard let dockItem = item as? [String: Any] else {
                        throw ThemeCodingError.invalidTheme("A dock item must be an object.")
                    }
                    try requireKeys(dockItem, allowed: ["id", "title", "symbolName", "bundleIdentifier", "pinned"], context: "dock item")
                }
            }
            if let favorites = settings["launcherFavorites"] as? [Any] {
                for item in favorites {
                    guard let favorite = item as? [String: Any] else {
                        throw ThemeCodingError.invalidTheme("A launcher favorite must be an object.")
                    }
                    try requireKeys(favorite, allowed: ["id", "title", "bundleIdentifier", "groupName"], context: "launcher favorite")
                }
            }
        }
    }

    private static func scanOverrideColors(_ overrides: [String: Any]) throws {
        for key in ["background", "foreground", "accent", "borderColor"] {
            try scanColor(overrides[key], name: key)
        }
    }

    private static func scanColor(_ value: Any?, name: String) throws {
        guard let color = value as? [String: Any] else { return }
        try requireKeys(color, allowed: ["hex", "opacity"], context: name)
    }

    private static let overrideKeys: Set<String> = [
        "background", "foreground", "accent", "cornerRadius", "opacity", "fontSize",
        "fontDesign", "fontWeight", "shadowEnabled", "borderWidth", "borderColor"
    ]

    private static let styleKeys: Set<String> = [
        "inheritBackground", "background", "foreground", "inheritAccent", "accent",
        "inheritCornerRadius", "cornerRadius", "opacity", "inheritTypography", "fontScale",
        "fontSize", "fontDesign", "fontWeight", "shadowEnabled", "borderWidth", "borderColor"
    ]

    private static func schemaVersion(in document: [String: Any]) throws -> Int {
        guard let raw = document["schemaVersion"] else {
            throw ThemeCodingError.invalidTheme("The document is missing schemaVersion.")
        }
        if let version = raw as? Int {
            return version
        }
        if let version = raw as? Double, version.isFinite, version.rounded() == version, abs(version) < 1_000 {
            return Int(version)
        }
        throw ThemeCodingError.invalidTheme("schemaVersion must be a whole number.")
    }

    private static func requireKeys(_ object: [String: Any], allowed: Set<String>, context: String) throws {
        for key in object.keys where !allowed.contains(key) {
            throw ThemeCodingError.invalidTheme("“\(key)” is not allowed in a \(context). Theme files cannot carry extra data.")
        }
    }

    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from object: [String: Any], name: String) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ThemeCodingError.invalidTheme("The \(name) could not be read. \(error.localizedDescription)")
        }
    }
}
