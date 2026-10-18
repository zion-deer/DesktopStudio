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
                    DockItem(id: UUID(), title: "Finder", symbolName: "folder"),
                    DockItem(id: UUID(), title: "Safari", symbolName: "safari"),
                    DockItem(id: UUID(), title: "Mail", symbolName: "envelope"),
                    DockItem(id: UUID(), title: "Music", symbolName: "music.note")
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
        }
    }
}
