import Foundation

struct DecodedTheme: Equatable {
    var theme: Theme
    var warnings: [String]
}

enum ThemeCoding {
    static func encode(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(ThemeDocument(theme: theme))
        } catch let error as ThemeCodingError {
            throw map(error, file: "theme")
        } catch {
            throw ThemePersistenceError.invalidDocument(file: "theme", reason: error.localizedDescription)
        }
    }

    static func decode(_ data: Data, file: String) throws -> DecodedTheme {
        try ThemeSafety.checkSize(data, file: file)
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ThemePersistenceError.invalidDocument(file: file, reason: "The file is not valid JSON.")
        }
        guard let documentObject = parsed as? [String: Any] else {
            throw ThemePersistenceError.invalidDocument(file: file, reason: "A theme document must be a JSON object.")
        }

        let prepared: PreparedThemeDocument
        do {
            try ThemeSafety.scan(documentObject)
            prepared = try ThemeMigration.prepare(documentObject)
        } catch let error as ThemeCodingError {
            throw map(error, file: file)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: ThemeDocument
        do {
            document = try decoder.decode(ThemeDocument.self, from: prepared.json)
            try document.theme.validate()
        } catch let error as ThemeCodingError {
            throw map(error, file: file)
        } catch let error as DecodingError {
            throw ThemePersistenceError.invalidDocument(file: file, reason: describe(error))
        } catch {
            throw ThemePersistenceError.invalidDocument(file: file, reason: error.localizedDescription)
        }
        return DecodedTheme(theme: document.theme, warnings: prepared.warnings)
    }

    private static func map(_ error: ThemeCodingError, file: String) -> ThemePersistenceError {
        switch error {
        case .unsupportedSchema(let version):
            return .unsupportedSchema(file: file, version: version)
        case .invalidTheme(let reason):
            return .invalidDocument(file: file, reason: reason)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Expected \(type) at \(path(context))."
        case .valueNotFound(let type, let context):
            return "Missing \(type) at \(path(context))."
        case .keyNotFound(let key, let context):
            return "Missing “\(key.stringValue)” in \(path(context))."
        case .dataCorrupted(let context):
            let location = path(context)
            if context.debugDescription.isEmpty {
                return "The data at \(location) is invalid."
            }
            return "\(context.debugDescription) (\(location))"
        @unknown default:
            return "The JSON could not be read."
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        let parts = context.codingPath.map(\.stringValue)
        return parts.isEmpty ? "the document" : parts.joined(separator: ".")
    }
}

