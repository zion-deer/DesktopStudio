import Foundation

/// Bounds for theme documents. These limits are part of the schema, not the editor UI.
enum ThemeLimits {
    static let maxDocumentBytes = 1_048_576
    static let maxDepth = 8
    static let maxObjectKeys = 64
    static let maxArrayCount = 256
    static let maxComponents = 200
    static let maxDockItems = 32
    static let maxNameLength = 80
    static let maxBodyLength = 4_000
    static let maxSymbolLength = 64
    static let maxBundleIdentifierLength = 200
    static let maxComponentLength: Double = 10_000
    static let maxAbsolutePosition: Double = 100_000
    static let maxZIndex = 10_000
    static let maxSpacing: Double = 64
    static let maxFontScale: Double = 8
    static let minFontScale: Double = 0.25

    static let forbiddenKeys: Set<String> = [
        "script", "javascript", "executable", "command", "shell", "eval",
        "code", "filepath", "path", "url", "href"
    ]
}
