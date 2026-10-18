import XCTest
@testable import DesktopStudio

final class DockConfigurationTests: XCTestCase {
    func testOlderDockItemsDefaultToPinnedWithoutABundleIdentifier() throws {
        var theme = SampleTheme.blank(name: "Legacy")
        theme.components = [
            DesktopComponent(
                id: UUID(),
                type: .dock,
                name: "Dock",
                frame: ComponentFrame(x: 40, y: 40, width: 320, height: 72, zIndex: 1),
                overrides: AppearanceOverrides(),
                settings: .standard(for: .dock)
            )
        ]
        let data = try ThemeCoding.encode(theme)
        let object = try JSONSerialization.jsonObject(with: data)
        let stripped = Self.removing(
            ["pinned", "dockIconSize", "dockSpacing", "dockPadding", "dockAlignment", "dockEdge", "launchAtLogin"],
            from: object
        )
        let legacy = try JSONSerialization.data(withJSONObject: stripped)
        let decoded = try ThemeCoding.decode(legacy, file: "legacy.json").theme
        let dock = try XCTUnwrap(decoded.components.first)
        XCTAssertEqual(dock.settings.dockEdge, .bottom)
        XCTAssertEqual(dock.settings.dockAlignment, .center)
        XCTAssertEqual(dock.settings.dockIconSize, DockLayout.defaultIconSize)
        XCTAssertFalse(dock.settings.launchAtLogin)
        XCTAssertTrue(dock.settings.dockItems.allSatisfy(\.pinned))
    }

    private static func removing(_ keys: Set<String>, from value: Any) -> Any {
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

    func testDockMetricsRoundTripAndRejectOutOfRangeSizes() throws {
        var settings = ComponentSettings.standard(for: .dock)
        settings.dockIconSize = 72
        settings.dockSpacing = 12
        settings.dockPadding = 16
        settings.dockAlignment = .trailing
        settings.dockEdge = .left
        settings.launchAtLogin = true
        settings.dockItems[0].pinned = false
        var theme = SampleTheme.blank(name: "Metrics")
        theme.components = [
            DesktopComponent(
                id: UUID(),
                type: .dock,
                name: "Dock",
                frame: ComponentFrame(x: 0, y: 0, width: 80, height: 240, zIndex: 1),
                overrides: AppearanceOverrides(),
                settings: settings
            )
        ]
        let decoded = try ThemeCoding.decode(try ThemeCoding.encode(theme), file: "metrics.json").theme
        XCTAssertEqual(decoded.components[0].settings.dockIconSize, 72)
        XCTAssertEqual(decoded.components[0].settings.dockEdge, .left)
        XCTAssertEqual(decoded.components[0].settings.dockAlignment, .trailing)
        XCTAssertTrue(decoded.components[0].settings.launchAtLogin)
        XCTAssertFalse(decoded.components[0].settings.dockItems[0].pinned)

        theme.components[0].settings.dockIconSize = 8
        XCTAssertThrowsError(try theme.validate())
    }

    func testEdgeSnapAndAlignmentStayInsideTheCanvas() {
        let canvas = CanvasSettings(
            width: 1000,
            height: 500,
            style: .solid,
            background: ThemeColor(hex: "#10141C"),
            gradientEnd: ThemeColor(hex: "#10141C")
        )
        let frame = ComponentFrame(x: 40, y: 20, width: 200, height: 80, zIndex: 1)
        let bottom = DockLayout.snapped(frame, edge: .bottom, canvas: canvas)
        XCTAssertEqual(bottom.y, 420, accuracy: 0.001)
        XCTAssertEqual(bottom.x, 40, accuracy: 0.001)

        let centered = DockLayout.aligned(bottom, alignment: .center, edge: .bottom, canvas: canvas)
        XCTAssertEqual(centered.x, 400, accuracy: 0.001)
        XCTAssertEqual(centered.y, 420, accuracy: 0.001)

        let right = DockLayout.snapped(frame, edge: .right, canvas: canvas)
        XCTAssertEqual(right.x, 800, accuracy: 0.001)

        let size = DockLayout.contentSize(itemCount: 3, iconSize: 40, spacing: 10, padding: 8, edge: .bottom)
        XCTAssertEqual(size.width, 156, accuracy: 0.001)
        XCTAssertEqual(size.height, 56, accuracy: 0.001)
        let vertical = DockLayout.contentSize(itemCount: 3, iconSize: 40, spacing: 10, padding: 8, edge: .left)
        XCTAssertEqual(vertical.width, 56, accuracy: 0.001)
        XCTAssertEqual(vertical.height, 156, accuracy: 0.001)
    }

    func testMissingAndEmptyApplicationsDoNotLaunch() {
        XCTAssertEqual(DockLaunch.problem(bundleIdentifier: "  ", isInstalled: true), .missingIdentifier)
        XCTAssertEqual(DockLaunch.problem(bundleIdentifier: "com.example.gone", isInstalled: false), .notInstalled)
        XCTAssertNil(DockLaunch.problem(bundleIdentifier: "com.apple.Safari", isInstalled: true))
    }
}

@MainActor
final class DockRuntimeTests: XCTestCase {
    func testApplyRegistersLoginItemFromTheThemeAndSwitchingThemesClearsIt() {
        let login = RecordingLoginItems()
        let launcher = RecordingLauncher()
        let dock = dockComponent(launchAtLogin: true)
        let runtime = makeRuntime(themeName: "Login On", dock: dock, login: login, launcher: launcher)
        let on = runtime.apply(theme: theme(name: "Login On", dock: dock))
        XCTAssertTrue(on.applied)
        XCTAssertEqual(login.enabled, true)

        var offDock = dock
        offDock.settings.launchAtLogin = false
        let off = runtime.apply(theme: theme(name: "Login Off", dock: offDock))
        XCTAssertTrue(off.applied)
        XCTAssertEqual(login.enabled, false)
        XCTAssertTrue(off.message.contains("system Dock"))
    }

    func testLaunchReportsAMissingApplicationAndOpensAnInstalledOne() {
        let login = RecordingLoginItems()
        let launcher = RecordingLauncher()
        launcher.installed = ["com.apple.Safari"]
        let dock = dockComponent(launchAtLogin: false)
        let runtime = makeRuntime(themeName: "Launch", dock: dock, login: login, launcher: launcher)
        let theme = theme(name: "Launch", dock: dock)
        _ = runtime.apply(theme: theme)
        runtime.launchApplication(bundleIdentifier: "com.missing.app", componentID: dock.id)
        XCTAssertEqual(launcher.opened.count, 0)
        runtime.launchApplication(bundleIdentifier: "com.apple.Safari", componentID: dock.id)
        XCTAssertEqual(launcher.opened.map(\.lastPathComponent), ["Safari.app"])
    }

    func testUnpinRemovesTheIconFromTheFittedDockButKeepsItInTheTheme() throws {
        var dock = dockComponent(launchAtLogin: false)
        dock.settings.dockItems[0].pinned = false
        let document = theme(name: "Pins", dock: dock)
        let store = InMemoryThemeStore(themes: [document])
        let runtime = DesktopRuntimeController(
            themeStore: store,
            sessionStore: MemoryRuntimeSessionStore(),
            screens: FakeDockScreens(),
            surfaces: RecordingSurfaceFactory(),
            loginItems: RecordingLoginItems(),
            appLauncher: RecordingLauncher()
        )
        _ = runtime.apply(theme: document)
        let saved = try XCTUnwrap(try store.loadLibrary().themes.first { $0.id == document.id })
        let savedDock = try XCTUnwrap(saved.components.first)
        XCTAssertEqual(savedDock.settings.dockItems.filter(\.pinned).count, savedDock.settings.dockItems.count - 1)
        XCTAssertFalse(savedDock.settings.dockItems[0].pinned)
        let pinnedCount = savedDock.settings.dockItems.filter(\.pinned).count
        let expected = DockLayout.contentSize(
            itemCount: pinnedCount,
            iconSize: savedDock.settings.dockIconSize,
            spacing: savedDock.settings.dockSpacing,
            padding: savedDock.settings.dockPadding,
            edge: savedDock.settings.dockEdge
        )
        XCTAssertEqual(savedDock.frame.width, expected.width, accuracy: 0.5)
        XCTAssertEqual(savedDock.frame.height, expected.height, accuracy: 0.5)
    }

    private func makeRuntime(
        themeName: String,
        dock: DesktopComponent,
        login: RecordingLoginItems,
        launcher: RecordingLauncher
    ) -> DesktopRuntimeController {
        let store = InMemoryThemeStore(themes: [theme(name: themeName, dock: dock)])
        return DesktopRuntimeController(
            themeStore: store,
            sessionStore: MemoryRuntimeSessionStore(),
            screens: FakeDockScreens(),
            surfaces: RecordingSurfaceFactory(),
            loginItems: login,
            appLauncher: launcher
        )
    }

    private func theme(name: String, dock: DesktopComponent) -> Theme {
        var theme = SampleTheme.blank(name: name)
        theme.canvas.width = 1000
        theme.canvas.height = 500
        theme.components = [dock]
        return theme
    }

    private func dockComponent(launchAtLogin: Bool) -> DesktopComponent {
        var settings = ComponentSettings.standard(for: .dock)
        settings.launchAtLogin = launchAtLogin
        settings.dockItems = [
            DockItem(id: UUID(), title: "Finder", symbolName: "folder", bundleIdentifier: "com.apple.finder"),
            DockItem(id: UUID(), title: "Safari", symbolName: "safari", bundleIdentifier: "com.apple.Safari")
        ]
        return DesktopComponent(
            id: UUID(),
            type: .dock,
            name: "Dock",
            frame: ComponentFrame(x: 100, y: 100, width: 300, height: 70, zIndex: 1),
            overrides: AppearanceOverrides(),
            settings: settings
        )
    }
}

private final class RecordingLoginItems: LoginItemRegistering {
    var enabled: Bool?
    func apply(enabled: Bool) -> String? {
        self.enabled = enabled
        return nil
    }
}

private final class RecordingLauncher: ApplicationLaunching {
    var installed: Set<String> = []
    var opened: [URL] = []

    func applicationURL(bundleIdentifier: String) -> URL? {
        guard installed.contains(bundleIdentifier) else { return nil }
        return URL(fileURLWithPath: "/Applications/Safari.app")
    }

    func openApplication(at url: URL, completion: @escaping (String?) -> Void) {
        opened.append(url)
        completion(nil)
    }
}

@MainActor
private final class FakeDockScreens: ScreenProviding {
    func screens() -> [RuntimeDisplay] {
        [
            RuntimeDisplay(
                id: 1,
                frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
                visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500),
                isMain: true
            )
        ]
    }
}
