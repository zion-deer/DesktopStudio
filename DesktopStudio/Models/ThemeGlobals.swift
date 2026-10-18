import Foundation

struct ThemeTypography: Codable, Hashable {
    var fontDesign: StudioFontDesign
    var fontWeight: StudioFontWeight
    var baseFontSize: Double
}

/// Default look for one component type. Inheritance flags point at the theme globals.
struct ComponentStyle: Codable, Hashable {
    var inheritBackground: Bool
    var background: ThemeColor
    var foreground: ThemeColor
    var inheritAccent: Bool
    var accent: ThemeColor
    var inheritCornerRadius: Bool
    var cornerRadius: Double
    var opacity: Double
    var inheritTypography: Bool
    var fontScale: Double
    var fontSize: Double
    var fontDesign: StudioFontDesign
    var fontWeight: StudioFontWeight
    var shadowEnabled: Bool
    var borderWidth: Double
    var borderColor: ThemeColor

    func validate(as name: String) throws {
        try ThemeValidation.requireUnit(opacity, "\(name) opacity")
        try ThemeValidation.requireUnit(background.opacity, "\(name) background opacity")
        try ThemeValidation.requireRange(cornerRadius, 0...ComponentAppearance.maximumCornerRadius, "\(name) corner radius")
        try ThemeValidation.requireRange(fontSize, ComponentAppearance.minimumFontSize...ComponentAppearance.maximumFontSize, "\(name) font size")
        try ThemeValidation.requireRange(fontScale, ThemeLimits.minFontScale...ThemeLimits.maxFontScale, "\(name) font scale")
        try ThemeValidation.requireRange(borderWidth, 0...ComponentAppearance.maximumBorderWidth, "\(name) border width")
    }
}

struct ComponentStyleSheet: Codable, Hashable {
    var clock: ComponentStyle
    var text: ComponentStyle
    var appShortcut: ComponentStyle
    var dock: ComponentStyle
    var notes: ComponentStyle
    var launcher: ComponentStyle

    init(
        clock: ComponentStyle,
        text: ComponentStyle,
        appShortcut: ComponentStyle,
        dock: ComponentStyle,
        notes: ComponentStyle,
        launcher: ComponentStyle
    ) {
        self.clock = clock
        self.text = text
        self.appShortcut = appShortcut
        self.dock = dock
        self.notes = notes
        self.launcher = launcher
    }

    subscript(type: ComponentType) -> ComponentStyle {
        get {
            switch type {
            case .clock: clock
            case .text: text
            case .appShortcut: appShortcut
            case .dock: dock
            case .notes: notes
            case .launcher: launcher
            }
        }
        set {
            switch type {
            case .clock: clock = newValue
            case .text: text = newValue
            case .appShortcut: appShortcut = newValue
            case .dock: dock = newValue
            case .notes: notes = newValue
            case .launcher: launcher = newValue
            }
        }
    }

    func validate() throws {
        try clock.validate(as: "Clock style")
        try text.validate(as: "Text style")
        try appShortcut.validate(as: "App shortcut style")
        try dock.validate(as: "Dock style")
        try notes.validate(as: "Notes style")
        try launcher.validate(as: "Launcher style")
    }

    private enum CodingKeys: String, CodingKey {
        case clock, text, appShortcut, dock, notes, launcher
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = try container.decode(ComponentStyle.self, forKey: .clock)
        text = try container.decode(ComponentStyle.self, forKey: .text)
        appShortcut = try container.decode(ComponentStyle.self, forKey: .appShortcut)
        dock = try container.decode(ComponentStyle.self, forKey: .dock)
        notes = try container.decode(ComponentStyle.self, forKey: .notes)
        launcher = try container.decodeIfPresent(ComponentStyle.self, forKey: .launcher) ?? Self.fallbackLauncher
    }

    static let fallbackLauncher = ComponentStyle(
        inheritBackground: false,
        background: ThemeColor(hex: "#1C1C1E", opacity: 0.94),
        foreground: ThemeColor(hex: "#F5F5F7"),
        inheritAccent: true,
        accent: ThemeColor(hex: "#9DB7FF"),
        inheritCornerRadius: false,
        cornerRadius: 16,
        opacity: 1,
        inheritTypography: true,
        fontScale: 1,
        fontSize: 15,
        fontDesign: .standard,
        fontWeight: .regular,
        shadowEnabled: true,
        borderWidth: 1,
        borderColor: ThemeColor(hex: "#FFFFFF", opacity: 0.12)
    )
}

/// Theme-wide wallpaper is stored on the canvas. These globals cover accent, surfaces, type, and default component styles.
struct ThemeGlobals: Codable, Hashable {
    var accent: ThemeColor
    var background: ThemeColor
    var typography: ThemeTypography
    var spacing: Double
    var cornerRadius: Double
    var componentStyles: ComponentStyleSheet

    func validate() throws {
        try ThemeValidation.requireUnit(accent.opacity, "Accent opacity")
        try ThemeValidation.requireUnit(background.opacity, "Background opacity")
        try ThemeValidation.requireRange(
            typography.baseFontSize,
            ComponentAppearance.minimumFontSize...ComponentAppearance.maximumFontSize,
            "Base font size"
        )
        try ThemeValidation.requireRange(spacing, 0...ThemeLimits.maxSpacing, "Spacing")
        try ThemeValidation.requireRange(cornerRadius, 0...ComponentAppearance.maximumCornerRadius, "Theme corner radius")
        try componentStyles.validate()
    }

    /// Globals added when a schema 1 theme is migrated. The original component appearance becomes explicit overrides.
    static func importedLegacy(from canvas: CanvasSettings) -> ThemeGlobals {
        ThemeGlobals(
            accent: ThemeColor(hex: "#9DB7FF"),
            background: canvas.background,
            typography: ThemeTypography(fontDesign: .standard, fontWeight: .medium, baseFontSize: 16),
            spacing: 16,
            cornerRadius: 16,
            componentStyles: .legacy
        )
    }

    static var standard: ThemeGlobals { .minimalDark }

    static var minimalDark: ThemeGlobals {
        let accent = ThemeColor(hex: "#F2F2F2")
        let surface = ThemeColor(hex: "#16161A")
        return ThemeGlobals(
            accent: accent,
            background: surface,
            typography: ThemeTypography(fontDesign: .standard, fontWeight: .regular, baseFontSize: 18),
            spacing: 20,
            cornerRadius: 2,
            componentStyles: ComponentStyleSheet(
                clock: style(background: "#16161A", foreground: "#F5F5F5", accent: accent.hex, fontScale: 3.2, fontSize: 56, shadow: false, borderOpacity: 0.08),
                text: style(background: "#000000", backgroundOpacity: 0, foreground: "#F5F5F5", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 0, fontScale: 2.4, fontSize: 42, shadow: false),
                appShortcut: style(background: "#16161A", foreground: "#F5F5F5", accent: accent.hex, fontScale: 0.9, fontSize: 16, shadow: false, borderOpacity: 0.08),
                dock: style(background: "#101012", backgroundOpacity: 0.92, foreground: "#F5F5F5", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 18, fontScale: 1.1, fontSize: 18, shadow: false, borderOpacity: 0.08),
                notes: style(background: "#16161A", foreground: "#D0D0D0", accent: accent.hex, fontScale: 1.15, fontSize: 20, fontDesign: .serif, shadow: false, borderOpacity: 0.08),
                launcher: style(background: "#1C1C1E", backgroundOpacity: 0.94, foreground: "#F5F5F7", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 16, fontScale: 1, fontSize: 15, shadow: true, borderOpacity: 0.12)
            )
        )
    }

    static var windows: ThemeGlobals {
        let accent = ThemeColor(hex: "#0078D4")
        return ThemeGlobals(
            accent: accent,
            background: ThemeColor(hex: "#F3F3F3"),
            typography: ThemeTypography(fontDesign: .standard, fontWeight: .semibold, baseFontSize: 15),
            spacing: 10,
            cornerRadius: 4,
            componentStyles: ComponentStyleSheet(
                clock: style(background: "#1F1F1F", foreground: "#FFFFFF", inheritAccent: false, accent: "#60CDFF", inheritCornerRadius: false, cornerRadius: 8, inheritTypography: false, fontScale: 2.8, fontSize: 42, fontWeight: .semibold, shadow: true),
                text: style(background: "#000000", backgroundOpacity: 0, foreground: "#FFFFFF", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 0, inheritTypography: false, fontScale: 2.6, fontSize: 40, fontWeight: .semibold, shadow: false),
                appShortcut: style(background: "#F3F3F3", foreground: "#1A1A1A", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 4, fontScale: 1, fontSize: 15, fontWeight: .semibold, shadow: true, borderOpacity: 0.08),
                dock: style(background: "#1F1F1F", backgroundOpacity: 0.96, foreground: "#FFFFFF", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 0, fontScale: 1.15, fontSize: 18, shadow: true),
                notes: style(background: "#FFF4C4", foreground: "#1A1A1A", inheritAccent: false, accent: "#8A6A00", inheritCornerRadius: false, cornerRadius: 2, inheritTypography: false, fontScale: 1.2, fontSize: 18, fontDesign: .serif, fontWeight: .regular, shadow: true, borderOpacity: 0.08),
                launcher: style(background: "#F3F3F3", backgroundOpacity: 0.96, foreground: "#1A1A1A", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 8, inheritTypography: false, fontScale: 1, fontSize: 15, fontWeight: .regular, shadow: true, borderOpacity: 0.08)
            )
        )
    }

    static var futuristic: ThemeGlobals {
        let accent = ThemeColor(hex: "#39F3FF")
        let surface = ThemeColor(hex: "#0C1428")
        return ThemeGlobals(
            accent: accent,
            background: surface,
            typography: ThemeTypography(fontDesign: .rounded, fontWeight: .medium, baseFontSize: 16),
            spacing: 14,
            cornerRadius: 28,
            componentStyles: ComponentStyleSheet(
                clock: style(background: "#0C1428", backgroundOpacity: 0.82, foreground: "#E8FBFF", accent: accent.hex, fontScale: 3.5, fontSize: 56, fontDesign: .rounded, shadow: true, border: "#39F3FF", borderOpacity: 0.45),
                text: style(background: "#000000", backgroundOpacity: 0, foreground: "#E8FBFF", accent: accent.hex, fontScale: 2.6, fontSize: 42, fontDesign: .rounded, fontWeight: .semibold, shadow: false),
                appShortcut: style(background: "#101A33", backgroundOpacity: 0.9, foreground: "#E8FBFF", accent: accent.hex, fontScale: 1, fontSize: 16, fontDesign: .rounded, shadow: true, border: "#39F3FF", borderOpacity: 0.4),
                dock: style(background: "#070D1C", backgroundOpacity: 0.78, foreground: "#E8FBFF", accent: accent.hex, fontScale: 1.2, fontSize: 20, fontDesign: .rounded, shadow: true, border: "#39F3FF", borderOpacity: 0.35),
                notes: style(background: "#0C1428", foreground: "#D7F7FF", inheritBackground: true, accent: accent.hex, fontScale: 1.25, fontSize: 20, fontDesign: .rounded, shadow: true, border: "#39F3FF", borderOpacity: 0.35),
                launcher: style(background: "#101A33", backgroundOpacity: 0.92, foreground: "#E8FBFF", accent: accent.hex, inheritCornerRadius: false, cornerRadius: 22, fontScale: 1, fontSize: 16, fontDesign: .rounded, shadow: true, border: "#39F3FF", borderOpacity: 0.35)
            )
        )
    }

    private static func style(
        background: String,
        backgroundOpacity: Double = 1,
        foreground: String,
        inheritBackground: Bool = false,
        inheritAccent: Bool = true,
        accent: String,
        inheritCornerRadius: Bool = true,
        cornerRadius: Double = 16,
        opacity: Double = 1,
        inheritTypography: Bool = true,
        fontScale: Double,
        fontSize: Double,
        fontDesign: StudioFontDesign = .standard,
        fontWeight: StudioFontWeight = .medium,
        shadow: Bool,
        border: String = "#FFFFFF",
        borderOpacity: Double = 0,
        borderWidth: Double? = nil
    ) -> ComponentStyle {
        ComponentStyle(
            inheritBackground: inheritBackground,
            background: ThemeColor(hex: background, opacity: backgroundOpacity),
            foreground: ThemeColor(hex: foreground),
            inheritAccent: inheritAccent,
            accent: ThemeColor(hex: accent),
            inheritCornerRadius: inheritCornerRadius,
            cornerRadius: cornerRadius,
            opacity: opacity,
            inheritTypography: inheritTypography,
            fontScale: fontScale,
            fontSize: fontSize,
            fontDesign: fontDesign,
            fontWeight: fontWeight,
            shadowEnabled: shadow,
            borderWidth: borderWidth ?? (borderOpacity > 0 ? 1 : 0),
            borderColor: ThemeColor(hex: border, opacity: borderOpacity)
        )
    }
}

extension ComponentStyleSheet {
    static var legacy: ComponentStyleSheet {
        ThemeGlobals.minimalDark.componentStyles
    }
}

enum ThemeValidation {
    static func requireFinite(_ value: Double, _ name: String) throws {
        guard value.isFinite else {
            throw ThemeCodingError.invalidTheme("\(name) must be a finite number.")
        }
    }

    static func requireRange(_ value: Double, _ range: ClosedRange<Double>, _ name: String) throws {
        try requireFinite(value, name)
        guard range.contains(value) else {
            throw ThemeCodingError.invalidTheme("\(name) must be from \(range.lowerBound) to \(range.upperBound).")
        }
    }

    static func requireUnit(_ value: Double, _ name: String) throws {
        try requireRange(value, 0...1, name)
    }

    static func requireText(_ value: String, field: String, limit: Int, allowNewlines: Bool) throws {
        if value.count > limit {
            throw ThemeCodingError.invalidTheme("\(field) is longer than \(limit) characters.")
        }
        if value.contains("\0") || value.contains("\u{202E}") {
            throw ThemeCodingError.invalidTheme("\(field) contains a hidden character.")
        }
        let lowered = value.lowercased()
        if lowered.contains("javascript:") || lowered.contains("<script") || lowered.contains("osascript") || lowered.contains("file://") || lowered.contains("#!/") {
            throw ThemeCodingError.invalidTheme("\(field) cannot contain executable content.")
        }
        for scalar in value.unicodeScalars {
            if scalar.value < 32 && scalar != "\n" && scalar != "\t" {
                throw ThemeCodingError.invalidTheme("\(field) contains a control character.")
            }
            if scalar == "\n" && !allowNewlines {
                throw ThemeCodingError.invalidTheme("\(field) cannot contain a new line.")
            }
        }
    }

    static func requireIdentifier(_ value: String, field: String, limit: Int) throws {
        if value.isEmpty { return }
        try requireText(value, field: field, limit: limit, allowNewlines: false)
        if value.contains("..") || value.contains("/") || value.contains("\\") || value.hasPrefix("~") {
            throw ThemeCodingError.invalidTheme("\(field) cannot be a file path.")
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-")
        if value.rangeOfCharacter(from: allowed.inverted) != nil {
            throw ThemeCodingError.invalidTheme("\(field) contains a character that is not allowed.")
        }
    }
}
