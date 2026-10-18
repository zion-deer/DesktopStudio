import Foundation

enum ComponentType: String, Hashable, CaseIterable, Identifiable {
    case clock
    case text
    case appShortcut
    case dock
    case notes

    var id: String { rawValue }

    var libraryTitle: String {
        switch self {
        case .clock: "Clock"
        case .text: "Text"
        case .appShortcut: "App Shortcut"
        case .dock: "Dock"
        case .notes: "Notes"
        }
    }

    var libraryDetail: String {
        switch self {
        case .clock: "Time and date"
        case .text: "Title and paragraph"
        case .appShortcut: "A pinned application"
        case .dock: "A row of applications"
        case .notes: "A scratch pad"
        }
    }

    var symbolName: String {
        switch self {
        case .clock: "clock"
        case .text: "textformat"
        case .appShortcut: "square.grid.2x2"
        case .dock: "dock.rectangle"
        case .notes: "note.text"
        }
    }

    var defaultName: String { libraryTitle }

    var defaultWidth: Double {
        switch self {
        case .clock: 420
        case .text: 560
        case .appShortcut: 220
        case .dock: 720
        case .notes: 360
        }
    }

    var defaultHeight: Double {
        switch self {
        case .clock: 168
        case .text: 160
        case .appShortcut: 88
        case .dock: 74
        case .notes: 280
        }
    }
}

extension ComponentType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = ComponentType(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown component type “\(rawValue)”. Expected clock, text, appShortcut, dock, or notes."
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
