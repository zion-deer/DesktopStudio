import Foundation

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

    static func decode(_ data: Data, file: String) throws -> ThemeDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let version: Int
        do {
            version = try decoder.decode(SchemaEnvelope.self, from: data).schemaVersion
        } catch let error as DecodingError {
            throw ThemePersistenceError.invalidDocument(file: file, reason: describe(error))
        } catch {
            throw ThemePersistenceError.invalidDocument(file: file, reason: error.localizedDescription)
        }

        guard version == ThemeDocument.currentSchemaVersion else {
            throw ThemePersistenceError.unsupportedSchema(file: file, version: version)
        }

        let document: ThemeDocument
        do {
            document = try decoder.decode(ThemeDocument.self, from: data)
        } catch let error as DecodingError {
            throw ThemePersistenceError.invalidDocument(file: file, reason: describe(error))
        } catch {
            throw ThemePersistenceError.invalidDocument(file: file, reason: error.localizedDescription)
        }

        do {
            try document.theme.validate()
        } catch let error as ThemeCodingError {
            throw map(error, file: file)
        }
        return document
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

private struct SchemaEnvelope: Decodable {
    var schemaVersion: Int
}
