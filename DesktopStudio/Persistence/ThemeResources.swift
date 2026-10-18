import Foundation

enum ThemeResources {
    static func sampleThemeData(bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(forResource: "SampleTheme", withExtension: "json") else {
            throw ThemePersistenceError.missingSampleTheme
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ThemePersistenceError.unreadableFile("SampleTheme.json")
        }
    }
}
