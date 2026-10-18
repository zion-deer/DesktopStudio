import Foundation

enum SampleTheme {
    static let identifier = UUID(uuidString: "8F4C2A10-6B1E-4C3A-9D2F-1A7B6C5D4E30")!
    static let timestamp = Date(timeIntervalSince1970: 1_792_324_800)

    static func make() -> Theme {
        let canvas = CanvasSettings(
            width: 1440,
            height: 900,
            style: .gradient,
            background: ThemeColor(hex: "#0E1424"),
            gradientEnd: ThemeColor(hex: "#243656")
        )
        return Theme(
            id: identifier,
            name: "Night Harbor",
            createdAt: timestamp,
            updatedAt: timestamp,
            canvas: canvas,
            globals: .importedLegacy(from: canvas),
            components: [
                text,
                clock,
                shortcut(
                    id: "A1000000-0000-4000-8000-000000000003",
                    name: "Finder",
                    x: 56,
                    symbol: "folder",
                    bundleIdentifier: "com.apple.finder"
                ),
                shortcut(
                    id: "A1000000-0000-4000-8000-000000000004",
                    name: "Safari",
                    x: 282,
                    symbol: "safari",
                    bundleIdentifier: "com.apple.Safari"
                ),
                shortcut(
                    id: "A1000000-0000-4000-8000-000000000005",
                    name: "Music",
                    x: 508,
                    symbol: "music.note",
                    bundleIdentifier: "com.apple.Music"
                ),
                notes,
                dock
            ]
        )
    }

    static func blank(name: String) -> Theme {
        let now = Date()
        return Theme(
            id: UUID(),
            name: name,
            createdAt: now,
            updatedAt: now,
            canvas: CanvasSettings(
                width: 1440,
                height: 900,
                style: .solid,
                background: ThemeColor(hex: "#10141C"),
                gradientEnd: ThemeColor(hex: "#10141C")
            ),
            globals: .standard,
            components: []
        )
    }

    private static var text: DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!,
            type: .text,
            name: "Title",
            frame: ComponentFrame(x: 56, y: 56, width: 620, height: 190, zIndex: 1),
            overrides: appearance(
                background: "#000000",
                backgroundOpacity: 0,
                cornerRadius: 0,
                fontSize: 44,
                fontDesign: .standard,
                fontWeight: .semibold,
                shadow: false
            ),
            settings: settings(
                title: "Night Harbor",
                body: "Late session. Quiet screen. The dock stays close, notes stay open, and the clock keeps the hour."
            )
        )
    }

    private static var clock: DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!,
            type: .clock,
            name: "Clock",
            frame: ComponentFrame(x: 964, y: 56, width: 420, height: 168, zIndex: 2),
            overrides: appearance(
                background: "#121826",
                backgroundOpacity: 0.875,
                cornerRadius: 24,
                fontSize: 56,
                fontDesign: .rounded,
                fontWeight: .semibold,
                shadow: true,
                borderWidth: 1,
                borderOpacity: 0.125
            ),
            settings: settings(title: "Local time", showsDate: true)
        )
    }

    private static var notes: DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: "A1000000-0000-4000-8000-000000000006")!,
            type: .notes,
            name: "Notes",
            frame: ComponentFrame(x: 964, y: 252, width: 420, height: 460, zIndex: 3),
            overrides: appearance(
                background: "#1A2236",
                foreground: "#E7ECF5",
                cornerRadius: 22,
                fontSize: 22,
                fontDesign: .serif,
                fontWeight: .medium,
                shadow: true,
                borderWidth: 1,
                borderOpacity: 0.125
            ),
            settings: settings(
                title: "Tonight",
                body: "Three things on the desk:\n— the time\n— a few apps\n— a place to think"
            )
        )
    }

    private static var dock: DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: "A1000000-0000-4000-8000-000000000007")!,
            type: .dock,
            name: "Dock",
            frame: ComponentFrame(x: 300, y: 792, width: 840, height: 72, zIndex: 4),
            overrides: appearance(
                background: "#0C101C",
                backgroundOpacity: 0.75,
                cornerRadius: 26,
                fontSize: 20,
                fontDesign: .standard,
                fontWeight: .medium,
                shadow: true,
                borderWidth: 1,
                borderOpacity: 0.125
            ),
            settings: settings(
                title: "Dock",
                dockItems: [
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-000000000008")!, title: "Finder", symbolName: "folder"),
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-000000000009")!, title: "Safari", symbolName: "safari"),
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-00000000000A")!, title: "Mail", symbolName: "envelope"),
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-00000000000B")!, title: "Messages", symbolName: "message"),
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-00000000000C")!, title: "Music", symbolName: "music.note"),
                    DockItem(id: UUID(uuidString: "A1000000-0000-4000-8000-00000000000D")!, title: "System Settings", symbolName: "gearshape")
                ]
            )
        )
    }

    private static func shortcut(
        id: String,
        name: String,
        x: Double,
        symbol: String,
        bundleIdentifier: String
    ) -> DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: id)!,
            type: .appShortcut,
            name: name,
            frame: ComponentFrame(x: x, y: 292, width: 210, height: 88, zIndex: 2),
            overrides: appearance(
                background: "#161C2E",
                backgroundOpacity: 0.875,
                cornerRadius: 18,
                fontSize: 16,
                fontDesign: .standard,
                fontWeight: .semibold,
                shadow: true,
                borderWidth: 1,
                borderOpacity: 0.125
            ),
            settings: settings(title: name, symbolName: symbol, bundleIdentifier: bundleIdentifier)
        )
    }

    private static func appearance(
        background: String,
        backgroundOpacity: Double = 1,
        foreground: String = "#F4F7FB",
        accent: String = "#9DB7FF",
        cornerRadius: Double,
        fontSize: Double,
        fontDesign: StudioFontDesign,
        fontWeight: StudioFontWeight,
        shadow: Bool,
        borderWidth: Double = 0,
        borderOpacity: Double = 0
    ) -> AppearanceOverrides {
        AppearanceOverrides(
            background: ThemeColor(hex: background, opacity: backgroundOpacity),
            foreground: ThemeColor(hex: foreground),
            accent: ThemeColor(hex: accent),
            cornerRadius: cornerRadius,
            opacity: 1,
            fontSize: fontSize,
            fontDesign: fontDesign,
            fontWeight: fontWeight,
            shadowEnabled: shadow,
            borderWidth: borderWidth,
            borderColor: ThemeColor(hex: "#FFFFFF", opacity: borderOpacity)
        )
    }

    private static func settings(
        title: String,
        body: String = "",
        symbolName: String = "",
        bundleIdentifier: String = "",
        showsDate: Bool = false,
        dockItems: [DockItem] = []
    ) -> ComponentSettings {
        ComponentSettings(
            title: title,
            body: body,
            symbolName: symbolName,
            bundleIdentifier: bundleIdentifier,
            timeFormat: .system,
            showsDate: showsDate,
            showsSeconds: false,
            dockItems: dockItems
        )
    }
}
