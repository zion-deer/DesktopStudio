import Foundation

enum TimeFormat: String, Codable, Hashable, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }
}

struct DockItem: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var symbolName: String
    /// Launch Services identifier. Empty until an app is chosen. A path is never stored.
    var bundleIdentifier: String
    /// Pinned items stay on the custom dock. Unpinned items remain in the theme so they can be pinned again.
    var pinned: Bool

    init(id: UUID, title: String, symbolName: String, bundleIdentifier: String = "", pinned: Bool = true) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.bundleIdentifier = bundleIdentifier
        self.pinned = pinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, symbolName, bundleIdentifier, pinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? ""
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(pinned, forKey: .pinned)
    }
}

/// Where icons sit along the custom dock. This does not move the system Dock.
enum DockAlignment: String, Codable, Hashable, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    func title(for edge: DockEdge) -> String {
        switch edge {
        case .left, .right:
            switch self {
            case .leading: return "Top"
            case .center: return "Center"
            case .trailing: return "Bottom"
            }
        case .top, .bottom:
            switch self {
            case .leading: return "Left"
            case .center: return "Center"
            case .trailing: return "Right"
            }
        }
    }
}

/// Screen edge used by the custom dock window. Placement uses the display's visible frame.
enum DockEdge: String, Codable, Hashable, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }

    var isVertical: Bool {
        self == .left || self == .right
    }
}

/// A pinned application in the launcher. Group names organize the pinned list.
struct LauncherFavorite: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var bundleIdentifier: String
    var groupName: String

    init(id: UUID, title: String, bundleIdentifier: String, groupName: String = "Pinned") {
        self.id = id
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.groupName = groupName.isEmpty ? "Pinned" : groupName
    }
}

/// Where the launcher window sits. Size stays on the component frame.
enum LauncherPlacement: String, Codable, Hashable, CaseIterable, Identifiable {
    case center
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .center: "Center"
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

struct ComponentSettings: Codable, Hashable {
    var title: String
    var body: String
    var symbolName: String
    var bundleIdentifier: String
    var timeFormat: TimeFormat
    var showsDate: Bool
    var showsSeconds: Bool
    var dockItems: [DockItem]
    var dockIconSize: Double
    var dockSpacing: Double
    var dockPadding: Double
    var dockAlignment: DockAlignment
    var dockEdge: DockEdge
    /// When true, applying this theme asks macOS to open Desktop Studio at login.
    var launchAtLogin: Bool
    var launcherFavorites: [LauncherFavorite]
    var launcherSpacing: Double
    var launcherPlacement: LauncherPlacement
    var launcherShortcutKey: String
    var launcherShortcutModifiers: [String]

    init(
        title: String,
        body: String,
        symbolName: String,
        bundleIdentifier: String,
        timeFormat: TimeFormat,
        showsDate: Bool,
        showsSeconds: Bool,
        dockItems: [DockItem],
        dockIconSize: Double = DockLayout.defaultIconSize,
        dockSpacing: Double = DockLayout.defaultSpacing,
        dockPadding: Double = DockLayout.defaultPadding,
        dockAlignment: DockAlignment = .center,
        dockEdge: DockEdge = .bottom,
        launchAtLogin: Bool = false,
        launcherFavorites: [LauncherFavorite] = [],
        launcherSpacing: Double = LauncherCatalog.defaultSpacing,
        launcherPlacement: LauncherPlacement = .center,
        launcherShortcutKey: String = LauncherShortcut.defaultKey,
        launcherShortcutModifiers: [String] = LauncherShortcut.defaultModifiers
    ) {
        self.title = title
        self.body = body
        self.symbolName = symbolName
        self.bundleIdentifier = bundleIdentifier
        self.timeFormat = timeFormat
        self.showsDate = showsDate
        self.showsSeconds = showsSeconds
        self.dockItems = dockItems
        self.dockIconSize = dockIconSize
        self.dockSpacing = dockSpacing
        self.dockPadding = dockPadding
        self.dockAlignment = dockAlignment
        self.dockEdge = dockEdge
        self.launchAtLogin = launchAtLogin
        self.launcherFavorites = launcherFavorites
        self.launcherSpacing = launcherSpacing
        self.launcherPlacement = launcherPlacement
        self.launcherShortcutKey = launcherShortcutKey
        self.launcherShortcutModifiers = launcherShortcutModifiers
    }

    static func standard(for type: ComponentType) -> ComponentSettings {
        switch type {
        case .clock:
            return ComponentSettings(
                title: "Local time",
                body: "",
                symbolName: "clock",
                bundleIdentifier: "",
                timeFormat: .system,
                showsDate: true,
                showsSeconds: false,
                dockItems: []
            )
        case .text:
            return ComponentSettings(
                title: "Title",
                body: "Write something that belongs on this desktop.",
                symbolName: "textformat",
                bundleIdentifier: "",
                timeFormat: .system,
                showsDate: false,
                showsSeconds: false,
                dockItems: []
            )
        case .appShortcut:
            return ComponentSettings(
                title: "Safari",
                body: "",
                symbolName: "safari",
                bundleIdentifier: "com.apple.Safari",
                timeFormat: .system,
                showsDate: false,
                showsSeconds: false,
                dockItems: []
            )
        case .dock:
            return ComponentSettings(
                title: "Dock",
                body: "",
                symbolName: "dock.rectangle",
                bundleIdentifier: "",
                timeFormat: .system,
                showsDate: false,
                showsSeconds: false,
                dockItems: [
                    DockItem(id: UUID(), title: "Finder", symbolName: "folder", bundleIdentifier: "com.apple.finder"),
                    DockItem(id: UUID(), title: "Safari", symbolName: "safari", bundleIdentifier: "com.apple.Safari"),
                    DockItem(id: UUID(), title: "Mail", symbolName: "envelope", bundleIdentifier: "com.apple.mail"),
                    DockItem(id: UUID(), title: "Music", symbolName: "music.note", bundleIdentifier: "com.apple.Music")
                ]
            )
        case .notes:
            return ComponentSettings(
                title: "Notes",
                body: "Jot a thought.",
                symbolName: "note.text",
                bundleIdentifier: "",
                timeFormat: .system,
                showsDate: false,
                showsSeconds: false,
                dockItems: []
            )
        case .launcher:
            return ComponentSettings(
                title: "Launcher",
                body: "",
                symbolName: "magnifyingglass",
                bundleIdentifier: "",
                timeFormat: .system,
                showsDate: false,
                showsSeconds: false,
                dockItems: [],
                launcherFavorites: [
                    LauncherFavorite(id: UUID(), title: "Finder", bundleIdentifier: "com.apple.finder", groupName: "Everyday"),
                    LauncherFavorite(id: UUID(), title: "Safari", bundleIdentifier: "com.apple.Safari", groupName: "Everyday")
                ]
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title, body, symbolName, bundleIdentifier, timeFormat, showsDate, showsSeconds, dockItems
        case dockIconSize, dockSpacing, dockPadding, dockAlignment, dockEdge, launchAtLogin
        case launcherFavorites, launcherSpacing, launcherPlacement, launcherShortcutKey, launcherShortcutModifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        timeFormat = try container.decode(TimeFormat.self, forKey: .timeFormat)
        showsDate = try container.decode(Bool.self, forKey: .showsDate)
        showsSeconds = try container.decode(Bool.self, forKey: .showsSeconds)
        dockItems = try container.decode([DockItem].self, forKey: .dockItems)
        dockIconSize = try container.decodeIfPresent(Double.self, forKey: .dockIconSize) ?? DockLayout.defaultIconSize
        dockSpacing = try container.decodeIfPresent(Double.self, forKey: .dockSpacing) ?? DockLayout.defaultSpacing
        dockPadding = try container.decodeIfPresent(Double.self, forKey: .dockPadding) ?? DockLayout.defaultPadding
        dockAlignment = try container.decodeIfPresent(DockAlignment.self, forKey: .dockAlignment) ?? .center
        dockEdge = try container.decodeIfPresent(DockEdge.self, forKey: .dockEdge) ?? .bottom
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        launcherFavorites = try container.decodeIfPresent([LauncherFavorite].self, forKey: .launcherFavorites) ?? []
        launcherSpacing = try container.decodeIfPresent(Double.self, forKey: .launcherSpacing) ?? LauncherCatalog.defaultSpacing
        launcherPlacement = try container.decodeIfPresent(LauncherPlacement.self, forKey: .launcherPlacement) ?? .center
        launcherShortcutKey = try container.decodeIfPresent(String.self, forKey: .launcherShortcutKey) ?? LauncherShortcut.defaultKey
        launcherShortcutModifiers = try container.decodeIfPresent([String].self, forKey: .launcherShortcutModifiers) ?? LauncherShortcut.defaultModifiers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(timeFormat, forKey: .timeFormat)
        try container.encode(showsDate, forKey: .showsDate)
        try container.encode(showsSeconds, forKey: .showsSeconds)
        try container.encode(dockItems, forKey: .dockItems)
        try container.encode(dockIconSize, forKey: .dockIconSize)
        try container.encode(dockSpacing, forKey: .dockSpacing)
        try container.encode(dockPadding, forKey: .dockPadding)
        try container.encode(dockAlignment, forKey: .dockAlignment)
        try container.encode(dockEdge, forKey: .dockEdge)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(launcherFavorites, forKey: .launcherFavorites)
        try container.encode(launcherSpacing, forKey: .launcherSpacing)
        try container.encode(launcherPlacement, forKey: .launcherPlacement)
        try container.encode(launcherShortcutKey, forKey: .launcherShortcutKey)
        try container.encode(launcherShortcutModifiers, forKey: .launcherShortcutModifiers)
    }
}
