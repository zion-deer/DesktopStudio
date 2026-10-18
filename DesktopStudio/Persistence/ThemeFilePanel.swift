import AppKit
import UniformTypeIdentifiers

@MainActor
enum ThemeFilePanel {
    static func chooseImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Import Theme"
        panel.prompt = "Import"
        panel.message = "Choose a Desktop Studio theme JSON file."
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func chooseExportURL(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = suggestedName
        panel.title = "Export Theme"
        panel.prompt = "Export"
        panel.message = "Export writes the current design, including unsaved edits."
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

enum ThemeFileAccess {
    static func read(_ url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ThemePersistenceError.unreadableFile(url.lastPathComponent)
        }
    }

    static func write(_ data: Data, to url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ThemePersistenceError.writeFailed(file: url.lastPathComponent, reason: error.localizedDescription)
        }
    }
}
