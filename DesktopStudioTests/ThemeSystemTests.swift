import XCTest
@testable import DesktopStudio

@MainActor
final class ThemeSystemTests: XCTestCase {
    func testCurrentDocumentsUseSchema2() throws {
        let data = try ThemeCoding.encode(SampleTheme.blank(name: "Plain"))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let version = object?["schemaVersion"] as? Int ?? (object?["schemaVersion"] as? NSNumber)?.intValue
        XCTAssertEqual(version, 2)
        let decoded = try ThemeCoding.decode(data, file: "Plain.json")
        XCTAssertEqual(decoded.theme.name, "Plain")
        XCTAssertTrue(decoded.warnings.isEmpty)
    }

    func testBuiltInThemesRoundTripAndInherit() throws {
        for preset in BuiltInTheme.allCases {
            let theme = preset.make()
            let decoded = try ThemeCoding.decode(try ThemeCoding.encode(theme), file: "\(preset.title).json").theme
            XCTAssertEqual(decoded, theme)
            XCTAssertTrue(theme.components.allSatisfy(\.overrides.isEmpty))
            try theme.validate()
        }

        var theme = BuiltInTheme.futuristic.make()
        let notes = try XCTUnwrap(theme.components.first { $0.type == .notes })
        XCTAssertTrue(theme.globals.componentStyles[.notes].inheritBackground)
        XCTAssertEqual(StyleResolver.resolve(notes, theme: theme).background.hex, theme.globals.background.hex)
        theme.globals.background = ThemeColor(hex: "#112233")
        XCTAssertEqual(StyleResolver.resolve(notes, theme: theme).background.hex, "#112233")

        var clock = try XCTUnwrap(theme.components.first { $0.type == .clock })
        clock.overrides.accent = ThemeColor(hex: "#FF00AA")
        theme.components[theme.components.firstIndex { $0.id == clock.id }!] = clock
        theme.globals.accent = ThemeColor(hex: "#00FF00")
        XCTAssertEqual(StyleResolver.resolve(clock, theme: theme).accent.hex, "#FF00AA")
        clock.overrides.accent = nil
        XCTAssertEqual(StyleResolver.resolve(clock, theme: theme).accent.hex, "#00FF00")
    }

    func testSchema1MigratesAndMatchesTheSampleFactory() throws {
        let data = try ThemeResources.sampleThemeData()
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(raw?["schemaVersion"] as? Int ?? (raw?["schemaVersion"] as? NSNumber)?.intValue, 1)
        let decoded = try ThemeCoding.decode(data, file: "SampleTheme.json")
        XCTAssertEqual(decoded.theme, SampleTheme.make())
        XCTAssertTrue(decoded.warnings.isEmpty)
        let encoded = try ThemeCoding.encode(decoded.theme)
        let migrated = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertEqual(migrated?["schemaVersion"] as? Int ?? (migrated?["schemaVersion"] as? NSNumber)?.intValue, 2)
    }

    func testMalformedJSONDuplicateIDsInvalidColorsAndSizes() throws {
        XCTAssertThrowsError(try ThemeCoding.decode(Data("{".utf8), file: "Broken.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("not valid JSON"))
        }

        var duplicate = SampleTheme.make()
        duplicate.components[1].id = duplicate.components[0].id
        XCTAssertThrowsError(try ThemeCoding.decode(try ThemeCoding.encode(duplicate), file: "Dup.json"))

        var theme = BuiltInTheme.minimalDark.make()
        let badColor = String(decoding: try ThemeCoding.encode(theme), as: UTF8.self)
            .replacingOccurrences(of: "#F2F2F2", with: "#GG0000")
        XCTAssertThrowsError(try ThemeCoding.decode(Data(badColor.utf8), file: "Color.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("hex") || error.localizedDescription.contains("color") || error.localizedDescription.contains("Color"))
        }

        theme.components[0].frame.width = -20
        XCTAssertThrowsError(try theme.validate())

        theme = BuiltInTheme.minimalDark.make()
        theme.components[0].settings.body = "javascript:alert(1)"
        let payload = try ThemeCoding.encode(theme)
        XCTAssertThrowsError(try ThemeCoding.decode(payload, file: "Script.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("executable"))
        }

        theme = BuiltInTheme.minimalDark.make()
        theme.components[0].settings.bundleIdentifier = "../Library/LaunchAgents"
        XCTAssertThrowsError(try theme.validate())

        let oversized = Data(count: ThemeLimits.maxDocumentBytes + 1)
        XCTAssertThrowsError(try ThemeCoding.decode(oversized, file: "Huge.json")) { error in
            guard case ThemePersistenceError.oversizedFile = error else {
                return XCTFail("Expected oversized file, got \(error)")
            }
        }
    }

    func testRejectedExecutableKeyAndInvalidPath() throws {
        let json = #"{"schemaVersion":2,"script":"osascript","theme":{"name":"Bad"}}"#
        XCTAssertThrowsError(try ThemeCoding.decode(Data(json.utf8), file: "Bad.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("script"))
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopStudioPaths-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ThemeStore(directoryURL: directory)
        try Data("{".utf8).write(to: directory.appendingPathComponent("not-a-theme.json"))
        try store.save(SampleTheme.blank(name: "Kept"))
        let library = try store.loadLibrary()
        XCTAssertEqual(library.themes.map(\.name), ["Kept"])
        XCTAssertEqual(library.issues.map(\.file), ["not-a-theme.json"])
    }

    func testImportExportPreservesGlobalsAndAssignsNewIDs() throws {
        let store = InMemoryThemeStore(themes: [SampleTheme.blank(name: "Host")])
        let model = EditorModel(store: store)
        let original = BuiltInTheme.windows.make()
        try model.importTheme(data: try ThemeCoding.encode(original), file: "Windows Inspired.json")
        XCTAssertEqual(model.selectedTheme.name, "Windows Inspired")
        XCTAssertNotEqual(model.selectedTheme.id, original.id)
        XCTAssertEqual(model.selectedTheme.globals, original.globals)
        XCTAssertEqual(model.selectedTheme.components.count, original.components.count)
        XCTAssertNotEqual(Set(model.selectedTheme.components.map(\.id)), Set(original.components.map(\.id)))

        let exported = try model.exportedSelectedThemeData()
        let decoded = try ThemeCoding.decode(exported, file: "Export.json").theme
        XCTAssertEqual(decoded.globals.accent.hex, "#0078D4")
        XCTAssertEqual(decoded.components.count, original.components.count)
    }
}

@MainActor
final class ThemeEditorSystemTests: XCTestCase {
    func testEmptyLibraryInstallsTheThreeBuiltInThemes() {
        let model = EditorModel(store: InMemoryThemeStore(themes: []))
        XCTAssertEqual(Set(model.themes.map(\.name)), Set(BuiltInTheme.allCases.map(\.title)))
        XCTAssertEqual(model.selectedTheme.name, "Minimal Dark")
        XCTAssertNil(model.notice)
    }

    func testRenameDuplicateAndReset() throws {
        let model = EditorModel(store: InMemoryThemeStore(themes: [BuiltInTheme.futuristic.make()]))
        model.themeBinding(\.name, token: "name").wrappedValue = "Night Shift"
        XCTAssertEqual(model.selectedTheme.name, "Night Shift")

        let clock = try XCTUnwrap(model.selectedTheme.components.first { $0.type == .clock })
        model.select(clock.id)
        model.overrideBinding(\.accent, resolved: \.accent, token: "accent", fallback: ThemeColor(hex: "#000000")).wrappedValue = ThemeColor(hex: "#FF00AA")
        XCTAssertEqual(model.selectedComponent?.overrides.accent?.hex, "#FF00AA")
        model.themeBinding(\.globals.accent, token: "globals").wrappedValue = ThemeColor(hex: "#123456")
        XCTAssertEqual(model.selectedComponent?.resolvedAppearance(in: model.selectedTheme).accent.hex, "#FF00AA")
        model.resetSelectedAppearance()
        XCTAssertEqual(model.selectedComponent?.resolvedAppearance(in: model.selectedTheme).accent.hex, "#123456")
        XCTAssertTrue(model.selectedComponent?.overrides.isEmpty == true)

        model.resetGlobalStyle()
        XCTAssertEqual(model.selectedTheme.globals.accent.hex, BuiltInTheme.futuristic.make().globals.accent.hex)

        model.deleteSelectedComponent()
        XCTAssertNotEqual(model.selectedTheme.components.count, BuiltInTheme.futuristic.make().components.count)
        model.resetBuiltInContent()
        XCTAssertEqual(model.selectedTheme.components.count, BuiltInTheme.futuristic.make().components.count)
        XCTAssertEqual(model.selectedTheme.name, "Futuristic")
        model.undo()
        XCTAssertEqual(model.selectedTheme.name, "Night Shift")
    }

    func testDuplicateThemeKeepsAnIndependentCopy() {
        let model = EditorModel(store: InMemoryThemeStore(themes: [BuiltInTheme.minimalDark.make()]))
        model.duplicateSelectedTheme()
        XCTAssertEqual(model.themes.count, 2)
        XCTAssertNotEqual(model.selectedTheme.id, BuiltInTheme.minimalDark.themeID)
        XCTAssertEqual(model.selectedTheme.globals, BuiltInTheme.minimalDark.make().globals)
    }
}
