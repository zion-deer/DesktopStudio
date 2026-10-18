import Foundation

struct InstalledApplication: Equatable, Identifiable {
    var bundleIdentifier: String
    var name: String
    /// Which folder the catalog read. This is not written into the theme.
    var source: String

    var id: String { bundleIdentifier }
}

struct ApplicationCatalogResult: Equatable {
    var applications: [InstalledApplication]
    var warnings: [String]
}

enum LauncherCatalog {
    static let defaultSpacing = 8.0

    static func scan(roots: [URL], fileManager: FileManager = .default) -> ApplicationCatalogResult {
        var applications: [InstalledApplication] = []
        var warnings: [String] = []
        var seen = Set<String>()
        for root in roots {
            let source = root.lastPathComponent
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                warnings.append("Skipped \(root.path) because it is not a folder Desktop Studio can read.")
                continue
            }
            collect(root: root, source: source, fileManager: fileManager, depth: 0, seen: &seen, applications: &applications, warnings: &warnings)
        }
        applications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return ApplicationCatalogResult(applications: applications, warnings: warnings)
    }

    static func standardRoots(fileManager: FileManager = .default) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    private static func collect(
        root: URL,
        source: String,
        fileManager: FileManager,
        depth: Int,
        seen: inout Set<String>,
        applications: inout [InstalledApplication],
        warnings: inout [String]
    ) {
        guard depth < 4 else { return }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        } catch {
            warnings.append("Could not read \(root.lastPathComponent). \(error.localizedDescription)")
            return
        }
        for url in children {
            if url.pathExtension == "app" {
                if let app = readApplication(at: url, source: source), seen.insert(app.bundleIdentifier).inserted {
                    applications.append(app)
                }
                continue
            }
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                collect(root: url, source: source, fileManager: fileManager, depth: depth + 1, seen: &seen, applications: &applications, warnings: &warnings)
            }
        }
    }

    private static func readApplication(at url: URL, source: String) -> InstalledApplication? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String,
              !identifier.isEmpty
        else { return nil }
        let display = plist["CFBundleDisplayName"] as? String
        let bundleName = plist["CFBundleName"] as? String
        let name = display ?? bundleName ?? url.deletingPathExtension().lastPathComponent
        return InstalledApplication(bundleIdentifier: identifier, name: name, source: source)
    }
}

enum LauncherSearch {
    static func filter(_ applications: [InstalledApplication], query: String) -> [InstalledApplication] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = trimmed.isEmpty
            ? applications
            : applications.filter { app in
                app.name.localizedCaseInsensitiveContains(trimmed)
                    || app.bundleIdentifier.localizedCaseInsensitiveContains(trimmed)
            }
        return pool.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func grouped(_ favorites: [LauncherFavorite]) -> [(name: String, items: [LauncherFavorite])] {
        var order: [String] = []
        var buckets: [String: [LauncherFavorite]] = [:]
        for favorite in favorites {
            let name = favorite.groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            let group = name.isEmpty ? "Pinned" : name
            if buckets[group] == nil {
                order.append(group)
                buckets[group] = []
            }
            buckets[group, default: []].append(favorite)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    static func missingFavorites(_ favorites: [LauncherFavorite], installedIdentifiers: Set<String>) -> [LauncherFavorite] {
        favorites.filter { favorite in
            let identifier = favorite.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            return identifier.isEmpty || !installedIdentifiers.contains(identifier)
        }
    }
}

enum LauncherLayout {
    static func fitted(_ frame: ComponentFrame, placement: LauncherPlacement, canvas: CanvasSettings) -> ComponentFrame {
        var frame = frame.clamped(to: canvas)
        let margin = 24.0
        switch placement {
        case .center:
            frame.x = max((canvas.width - frame.width) / 2, 0)
            frame.y = max((canvas.height - frame.height) / 2, 0)
        case .top:
            frame.x = max((canvas.width - frame.width) / 2, 0)
            frame.y = margin
        case .bottom:
            frame.x = max((canvas.width - frame.width) / 2, 0)
            frame.y = max(canvas.height - frame.height - margin, 0)
        case .left:
            frame.x = margin
            frame.y = max((canvas.height - frame.height) / 2, 0)
        case .right:
            frame.x = max(canvas.width - frame.width - margin, 0)
            frame.y = max((canvas.height - frame.height) / 2, 0)
        }
        return frame.clamped(to: canvas)
    }
}

enum LauncherShortcut {
    static let defaultKey = "space"
    static let defaultModifiers = ["command", "option"]
    static let allowedModifiers: Set<String> = ["command", "option", "shift", "control"]

    static func validate(key: String, modifiers: [String], field: String) throws {
        let name = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard carbonKeyCode(for: name) != nil else {
            throw ThemeCodingError.invalidTheme("\(field) shortcut key must be a letter, a digit, or space.")
        }
        for modifier in modifiers {
            guard allowedModifiers.contains(modifier.lowercased()) else {
                throw ThemeCodingError.invalidTheme("\(field) shortcut uses an unknown modifier “\(modifier)”.")
            }
        }
    }

    /// Carbon virtual key codes for the keys this launcher accepts.
    static func carbonKeyCode(for name: String) -> UInt32? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key == "space" { return 49 }
        let letters: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
            "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46
        ]
        if let code = letters[key] { return code }
        let digits: [String: UInt32] = [
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29
        ]
        return digits[key]
    }

    /// Carbon modifier bits: command 256, shift 512, option 2048, control 4096.
    static func carbonModifiers(_ names: [String]) -> UInt32 {
        var bits: UInt32 = 0
        for name in names {
            switch name.lowercased() {
            case "command": bits |= 256
            case "shift": bits |= 512
            case "option": bits |= 2048
            case "control": bits |= 4096
            default: break
            }
        }
        return bits
    }
}
