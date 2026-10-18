import XCTest
@testable import DesktopStudio

final class ThemeStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ThemeStore(directoryURL: directory)
        let theme = SampleTheme.make()
        try store.save(theme)
        let library = try store.loadLibrary()
        XCTAssertEqual(library.themes, [theme])
        XCTAssertTrue(library.issues.isEmpty)
    }

    func testCorruptFileDoesNotHideValidThemes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ThemeStore(directoryURL: directory)
        try Data("{".utf8).write(to: directory.appendingPathComponent("Broken.json"))
        try store.save(SampleTheme.blank(name: "Kept"))
        let library = try store.loadLibrary()
        XCTAssertEqual(library.themes.map(\.name), ["Kept"])
        XCTAssertEqual(library.issues.count, 1)
        XCTAssertEqual(library.issues[0].file, "Broken.json")
    }

    func testDeleteRemovesTheFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ThemeStore(directoryURL: directory)
        let theme = SampleTheme.blank(name: "Temporary")
        try store.save(theme)
        try store.delete(id: theme.id)
        let library = try store.loadLibrary()
        XCTAssertTrue(library.themes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(for: theme.id).path))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
