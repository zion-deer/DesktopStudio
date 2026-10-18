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
        var warnings: [ThemeLoadIssue] = []
        for url in jsonURLs {
            let name = url.lastPathComponent
            guard Self.isInsideThemesDirectory(url, directory: directoryURL), Self.isThemeFilename(name) else {
                issues.append(ThemeLoadIssue(file: name, message: ThemePersistenceError.invalidThemePath(name).localizedDescription))
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let decoded = try ThemeCoding.decode(data, file: name)
                themes.append(decoded.theme)
                if !decoded.warnings.isEmpty {
                    warnings.append(ThemeLoadIssue(file: name, message: decoded.warnings.joined(separator: " ")))
                }
            } catch {
                issues.append(ThemeLoadIssue(file: name, message: error.localizedDescription))
            }
        }
        themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return ThemeLibrary(themes: themes, issues: issues, warnings: warnings)
    }

    static func isThemeFilename(_ name: String) -> Bool {
        guard name.lowercased().hasSuffix(".json") else { return false }
        let stem = String(name.dropLast(5))
        return UUID(uuidString: stem) != nil && !stem.contains("/") && !stem.contains("..")
    }

    static func isInsideThemesDirectory(_ url: URL, directory: URL) -> Bool {
        let folder = directory.resolvingSymlinksInPath().standardizedFileURL
        let parent = url.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL
        return parent == folder
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
