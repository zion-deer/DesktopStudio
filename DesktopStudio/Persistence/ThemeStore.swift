import Foundation

protocol ThemeStoring: AnyObject {
    func loadLibrary() throws -> ThemeLibrary
    func save(_ theme: Theme) throws
    func delete(id: UUID) throws
}

final class ThemeStore: ThemeStoring {
    let directoryURL: URL

    init(directoryURL: URL? = nil) throws {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = try Self.defaultThemesDirectory()
        }
        do {
            try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        } catch {
            throw ThemePersistenceError.directoryUnavailable(error.localizedDescription)
        }
    }

    func loadLibrary() throws -> ThemeLibrary {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw ThemePersistenceError.directoryUnavailable(error.localizedDescription)
        }

        let jsonURLs = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var themes: [Theme] = []
        var issues: [ThemeLoadIssue] = []
        for url in jsonURLs {
            do {
                let data = try Data(contentsOf: url)
                let document = try ThemeCoding.decode(data, file: url.lastPathComponent)
                themes.append(document.theme)
            } catch {
                issues.append(ThemeLoadIssue(file: url.lastPathComponent, message: error.localizedDescription))
            }
        }
        themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return ThemeLibrary(themes: themes, issues: issues)
    }

    func save(_ theme: Theme) throws {
        try theme.validate()
        let data = try ThemeCoding.encode(theme)
        let url = fileURL(for: theme.id)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ThemePersistenceError.writeFailed(file: url.lastPathComponent, reason: error.localizedDescription)
        }
    }

    func delete(id: UUID) throws {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw ThemePersistenceError.writeFailed(file: url.lastPathComponent, reason: error.localizedDescription)
        }
    }

    func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private static func defaultThemesDirectory() throws -> URL {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw ThemePersistenceError.directoryUnavailable(error.localizedDescription)
        }
        return base
            .appendingPathComponent("Desktop Studio", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }
}
