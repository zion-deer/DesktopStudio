import Foundation

enum ThemePersistenceError: LocalizedError, Equatable {
    case missingSampleTheme
    case unreadableFile(String)
    case invalidDocument(file: String, reason: String)
    case unsupportedSchema(file: String, version: Int)
    case oversizedFile(file: String, bytes: Int)
    case invalidThemePath(String)
    case writeFailed(file: String, reason: String)
    case directoryUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingSampleTheme:
            return "The sample theme could not be found in the application bundle."
        case .unreadableFile(let file):
            return "“\(file)” could not be read."
        case .invalidDocument(let file, let reason):
            return "“\(file)” is not a valid Desktop Studio theme. \(reason)"
        case .unsupportedSchema(let file, let version):
            return "“\(file)” uses theme schema version \(version), which this version of Desktop Studio does not open."
        case .oversizedFile(let file, let bytes):
            return "“\(file)” is \(bytes) bytes. Theme files must be \(ThemeLimits.maxDocumentBytes) bytes or smaller."
        case .invalidThemePath(let file):
            return "“\(file)” is not a theme file in the themes folder. Theme files are named with a UUID and stay inside that folder."
        case .writeFailed(let file, let reason):
            return "Could not save “\(file)”. \(reason)"
        case .directoryUnavailable(let reason):
            return "The themes folder is unavailable. \(reason)"
        }
    }
}

struct ThemeLoadIssue: Equatable {
    var file: String
    var message: String
}

struct ThemeLibrary: Equatable {
    var themes: [Theme]
    var issues: [ThemeLoadIssue]
    var warnings: [ThemeLoadIssue] = []
}
