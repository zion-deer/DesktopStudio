import Foundation

/// Themes shipped with the app. `make()` is the canonical document; export writes the same schema as any other theme.
enum BuiltInTheme: String, CaseIterable, Identifiable {
    case windows
    case minimalDark
    case futuristic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows: "Windows Inspired"
        case .minimalDark: "Minimal Dark"
        case .futuristic: "Futuristic"
        }
    }

    var themeID: UUID {
        switch self {
        case .windows: UUID(uuidString: "C1000000-0000-4000-8000-000000000001")!
        case .minimalDark: UUID(uuidString: "C2000000-0000-4000-8000-000000000001")!
        case .futuristic: UUID(uuidString: "C3000000-0000-4000-8000-000000000001")!
        }
    }

    func make() -> Theme {
        switch self {
        case .windows: Self.windowsTheme()
        case .minimalDark: Self.minimalTheme()
        case .futuristic: Self.futuristicTheme()
        }
    }

    static func matching(id: UUID) -> BuiltInTheme? {
        allCases.first { $0.themeID == id }
    }

    private static func windowsTheme() -> Theme {
        theme(
            id: BuiltInTheme.windows.themeID,
            name: BuiltInTheme.windows.title,
            canvas: CanvasSettings(
                width: 1440,
                height: 900,
                style: .gradient,
                background: ThemeColor(hex: "#0F5FA8"),
                gradientEnd: ThemeColor(hex: "#0A3D73")
            ),
            globals: .windows,
            components: [
                component(id: "C1000000-0000-4000-8000-000000000010", type: .text, name: "Title", frame: ComponentFrame(x: 48, y: 56, width: 680, height: 150, zIndex: 1), settings: settings(title: "Windows Inspired", body: "Tiles, a taskbar, and a light accent on a blue field.")),
                component(id: "C1000000-0000-4000-8000-000000000011", type: .clock, name: "Clock", frame: ComponentFrame(x: 980, y: 48, width: 400, height: 150, zIndex: 2), settings: settings(title: "Local time", showsDate: true)),
                component(id: "C1000000-0000-4000-8000-000000000012", type: .appShortcut, name: "Finder", frame: ComponentFrame(x: 48, y: 250, width: 220, height: 88, zIndex: 2), settings: settings(title: "Finder", symbolName: "folder", bundleIdentifier: "com.apple.finder")),
                component(id: "C1000000-0000-4000-8000-000000000013", type: .appShortcut, name: "Safari", frame: ComponentFrame(x: 284, y: 250, width: 220, height: 88, zIndex: 2), settings: settings(title: "Safari", symbolName: "safari", bundleIdentifier: "com.apple.Safari")),
                component(id: "C1000000-0000-4000-8000-000000000014", type: .notes, name: "Notes", frame: ComponentFrame(x: 980, y: 230, width: 400, height: 500, zIndex: 3), settings: settings(title: "Scratch pad", body: "A note sits beside the tiles.")),
                component(id: "C1000000-0000-4000-8000-000000000015", type: .dock, name: "Taskbar", frame: ComponentFrame(x: 0, y: 844, width: 1440, height: 56, zIndex: 4), settings: settings(title: "Taskbar", dockItems: dockItems(prefix: "C1000000-0000-4000-8000-00000000002"))),
                component(id: "C1000000-0000-4000-8000-000000000016", type: .launcher, name: "Start", frame: ComponentFrame(x: 48, y: 160, width: 420, height: 520, zIndex: 6), settings: settings(title: "Start", launcherFavorites: [
                    LauncherFavorite(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000030")!, title: "Finder", bundleIdentifier: "com.apple.finder", groupName: "Everyday"),
                    LauncherFavorite(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000031")!, title: "Safari", bundleIdentifier: "com.apple.Safari", groupName: "Everyday")
                ]))
            ]
        )
    }

    private static func minimalTheme() -> Theme {
        theme(
            id: BuiltInTheme.minimalDark.themeID,
            name: BuiltInTheme.minimalDark.title,
            canvas: CanvasSettings(
                width: 1440,
                height: 900,
                style: .solid,
                background: ThemeColor(hex: "#0B0B0C"),
                gradientEnd: ThemeColor(hex: "#0B0B0C")
            ),
            globals: .minimalDark,
            components: [
                component(id: "C2000000-0000-4000-8000-000000000010", type: .text, name: "Title", frame: ComponentFrame(x: 80, y: 96, width: 720, height: 180, zIndex: 1), settings: settings(title: "Minimal Dark", body: "Type, time, and a note. Little else.")),
                component(id: "C2000000-0000-4000-8000-000000000011", type: .clock, name: "Clock", frame: ComponentFrame(x: 80, y: 320, width: 520, height: 180, zIndex: 2), settings: settings(title: "", showsDate: true)),
                component(id: "C2000000-0000-4000-8000-000000000012", type: .notes, name: "Notes", frame: ComponentFrame(x: 860, y: 96, width: 480, height: 640, zIndex: 2), settings: settings(title: "Notes", body: "Keep the desktop quiet."))
            ]
        )
    }

    private static func futuristicTheme() -> Theme {
        theme(
            id: BuiltInTheme.futuristic.themeID,
            name: BuiltInTheme.futuristic.title,
            canvas: CanvasSettings(
                width: 1440,
                height: 900,
                style: .gradient,
                background: ThemeColor(hex: "#050816"),
                gradientEnd: ThemeColor(hex: "#12315A")
            ),
            globals: .futuristic,
            components: [
                component(id: "C3000000-0000-4000-8000-000000000010", type: .text, name: "Title", frame: ComponentFrame(x: 64, y: 64, width: 640, height: 160, zIndex: 1), settings: settings(title: "Futuristic", body: "Cyan edges, round surfaces, and a floating dock.")),
                component(id: "C3000000-0000-4000-8000-000000000011", type: .clock, name: "Clock", frame: ComponentFrame(x: 960, y: 64, width: 416, height: 176, zIndex: 2), settings: settings(title: "Local time", showsDate: true)),
                component(id: "C3000000-0000-4000-8000-000000000012", type: .appShortcut, name: "Safari", frame: ComponentFrame(x: 64, y: 280, width: 240, height: 92, zIndex: 2), settings: settings(title: "Safari", symbolName: "safari", bundleIdentifier: "com.apple.Safari")),
                component(id: "C3000000-0000-4000-8000-000000000013", type: .notes, name: "Notes", frame: ComponentFrame(x: 960, y: 272, width: 416, height: 420, zIndex: 3), settings: settings(title: "Log", body: "Notes inherit the theme background until you override them.")),
                component(id: "C3000000-0000-4000-8000-000000000014", type: .dock, name: "Dock", frame: ComponentFrame(x: 360, y: 790, width: 720, height: 72, zIndex: 4), settings: settings(title: "Dock", dockItems: dockItems(prefix: "C3000000-0000-4000-8000-00000000002")))
            ]
        )
    }

    private static func theme(
        id: UUID,
        name: String,
        canvas: CanvasSettings,
        globals: ThemeGlobals,
        components: [DesktopComponent]
    ) -> Theme {
        Theme(
            id: id,
            name: name,
            createdAt: SampleTheme.timestamp,
            updatedAt: SampleTheme.timestamp,
            canvas: canvas,
            globals: globals,
            components: components
        )
    }

    private static func component(
        id: String,
        type: ComponentType,
        name: String,
        frame: ComponentFrame,
        settings: ComponentSettings
    ) -> DesktopComponent {
        DesktopComponent(
            id: UUID(uuidString: id)!,
            type: type,
            name: name,
            frame: frame,
            overrides: AppearanceOverrides(),
            settings: settings
        )
    }

    private static func settings(
        title: String,
        body: String = "",
        symbolName: String = "",
        bundleIdentifier: String = "",
        showsDate: Bool = false,
        dockItems: [DockItem] = [],
        launcherFavorites: [LauncherFavorite] = []
    ) -> ComponentSettings {
        ComponentSettings(
            title: title,
            body: body,
            symbolName: symbolName,
            bundleIdentifier: bundleIdentifier,
            timeFormat: .system,
            showsDate: showsDate,
            showsSeconds: false,
            dockItems: dockItems,
            launcherFavorites: launcherFavorites
        )
    }

    private static func dockItems(prefix: String) -> [DockItem] {
        [
            DockItem(id: UUID(uuidString: prefix + "0")!, title: "Finder", symbolName: "folder", bundleIdentifier: "com.apple.finder"),
            DockItem(id: UUID(uuidString: prefix + "1")!, title: "Safari", symbolName: "safari", bundleIdentifier: "com.apple.Safari"),
            DockItem(id: UUID(uuidString: prefix + "2")!, title: "Mail", symbolName: "envelope", bundleIdentifier: "com.apple.mail"),
            DockItem(id: UUID(uuidString: prefix + "3")!, title: "Music", symbolName: "music.note", bundleIdentifier: "com.apple.Music")
        ]
    }
}
