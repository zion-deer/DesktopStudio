import Foundation

/// Session-only storage used when the themes folder cannot be created, and by previews and tests.
final class InMemoryThemeStore: ThemeStoring {
    private var stored: [UUID: Theme]

    init(themes: [Theme]) {
        stored = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0) })
    }

    func loadLibrary() throws -> ThemeLibrary {
        let themes = stored.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return ThemeLibrary(themes: themes, issues: [])
    }

    func save(_ theme: Theme) throws {
        try theme.validate()
        stored[theme.id] = theme
    }

    func delete(id: UUID) throws {
        stored[id] = nil
    }
}
