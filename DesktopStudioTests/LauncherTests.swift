import XCTest
@testable import DesktopStudio

final class LauncherTests: XCTestCase {
    func testSearchFiltersByNameAndBundleIdentifier() {
        let apps = [
            InstalledApplication(bundleIdentifier: "com.example.alpha", name: "Alpha", source: "Applications"),
            InstalledApplication(bundleIdentifier: "com.example.beta", name: "Beta Mail", source: "Applications"),
            InstalledApplication(bundleIdentifier: "org.other.gamma", name: "Gamma", source: "Applications")
        ]
        XCTAssertEqual(LauncherSearch.filter(apps, query: "  ").map(\.name), ["Alpha", "Beta Mail", "Gamma"])
        XCTAssertEqual(LauncherSearch.filter(apps, query: "alp").map(\.bundleIdentifier), ["com.example.alpha"])
        XCTAssertEqual(LauncherSearch.filter(apps, query: "MAIL").map(\.name), ["Beta Mail"])
        XCTAssertEqual(LauncherSearch.filter(apps, query: "org.other").map(\.name), ["Gamma"])
        XCTAssertTrue(LauncherSearch.filter(apps, query: "missing").isEmpty)
    }

    func testFavoritesStayGroupedAndMissingReferencesAreReported() {
        let favorites = [
            LauncherFavorite(id: UUID(), title: "Finder", bundleIdentifier: "com.apple.finder", groupName: "Everyday"),
            LauncherFavorite(id: UUID(), title: "Safari", bundleIdentifier: "com.apple.Safari", groupName: "Everyday"),
            LauncherFavorite(id: UUID(), title: "Gone", bundleIdentifier: "com.example.missing", groupName: "Work"),
            LauncherFavorite(id: UUID(), title: "Blank", bundleIdentifier: " ", groupName: "Work")
        ]
        let groups = LauncherSearch.grouped(favorites)
        XCTAssertEqual(groups.map(\.name), ["Everyday", "Work"])
        XCTAssertEqual(groups[0].items.map(\.title), ["Finder", "Safari"])
        let missing = LauncherSearch.missingFavorites(favorites, installedIdentifiers: ["com.apple.finder", "com.apple.Safari"])
        XCTAssertEqual(missing.map(\.title), ["Gone", "Blank"])

        let rows = LauncherList.rows(
            favorites: favorites,
            applications: [InstalledApplication(bundleIdentifier: "com.apple.finder", name: "Finder", source: "Applications")],
            query: ""
        )
        XCTAssertEqual(rows.filter(\.missing).map(\.title), ["Safari", "Gone", "Blank"])
        let searched = LauncherList.rows(
            favorites: favorites,
            applications: [InstalledApplication(bundleIdentifier: "com.example.notes", name: "Notes", source: "Applications")],
            query: "note"
        )
        XCTAssertEqual(searched.map(\.title), ["Notes"])
    }

    func testLauncherSettingsRoundTripAndRejectABadShortcut() throws {
        var settings = ComponentSettings.standard(for: .launcher)
        settings.launcherPlacement = .top
        settings.launcherSpacing = 14
        settings.launcherShortcutKey = "k"
        settings.launcherShortcutModifiers = ["command", "shift"]
        settings.launcherFavorites = [
            LauncherFavorite(id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!, title: "Finder", bundleIdentifier: "com.apple.finder", groupName: "Everyday")
        ]
        var theme = SampleTheme.blank(name: "Launcher")
        theme.components = [
            DesktopComponent(
                id: UUID(),
                type: .launcher,
                name: "Start",
                frame: ComponentFrame(x: 20, y: 20, width: 400, height: 500, zIndex: 1),
                overrides: AppearanceOverrides(),
                settings: settings
            )
        ]
        let decoded = try ThemeCoding.decode(try ThemeCoding.encode(theme), file: "launcher.json").theme
        XCTAssertEqual(decoded.components[0].settings.launcherPlacement, .top)
        XCTAssertEqual(decoded.components[0].settings.launcherSpacing, 14)
        XCTAssertEqual(decoded.components[0].settings.launcherShortcutKey, "k")
        XCTAssertEqual(decoded.components[0].settings.launcherFavorites[0].groupName, "Everyday")

        let object = try JSONSerialization.jsonObject(with: try ThemeCoding.encode(theme))
        let stripped = removing(["launcherFavorites", "launcherSpacing", "launcherPlacement", "launcherShortcutKey", "launcherShortcutModifiers"], from: object)
        let legacy = try ThemeCoding.decode(try JSONSerialization.data(withJSONObject: stripped), file: "legacy-launcher.json").theme
        XCTAssertTrue(legacy.components[0].settings.launcherFavorites.isEmpty)
        XCTAssertEqual(legacy.components[0].settings.launcherPlacement, .center)
        XCTAssertEqual(legacy.components[0].settings.launcherShortcutKey, LauncherShortcut.defaultKey)

        theme.components[0].settings.launcherShortcutKey = "../bin"
        XCTAssertThrowsError(try theme.validate())
    }

    func testCatalogReadsBundlesAndRecordsAnUnreadableRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let app = root.appendingPathComponent("Alpha.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.example.alpha</string>
        <key>CFBundleDisplayName</key><string>Alpha</string>
        </dict></plist>
        """
        try Data(plist.utf8).write(to: app.appendingPathComponent("Info.plist"))
        try Data("skip".utf8).write(to: root.appendingPathComponent("notes.txt"))
        let missing = root.appendingPathComponent("Missing", isDirectory: true)
        let result = LauncherCatalog.scan(roots: [root, missing])
        XCTAssertEqual(result.applications.map(\.name), ["Alpha"])
        XCTAssertEqual(result.applications[0].bundleIdentifier, "com.example.alpha")
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertEqual(LauncherShortcut.carbonKeyCode(for: "space"), 49)
        XCTAssertEqual(LauncherShortcut.carbonModifiers(["command", "option"]), 256 | 2048)
        try? FileManager.default.removeItem(at: root)
    }

    private func removing(_ keys: Set<String>, from value: Any) -> Any {
        if var dictionary = value as? [String: Any] {
            for key in keys {
                dictionary.removeValue(forKey: key)
            }
            for (key, nested) in dictionary {
                dictionary[key] = removing(keys, from: nested)
            }
            return dictionary
        }
        if let array = value as? [Any] {
            return array.map { removing(keys, from: $0) }
        }
        return value
    }
}
