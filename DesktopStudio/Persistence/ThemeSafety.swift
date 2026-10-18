import Foundation

/// Rejects documents that are too large, too deep, or that carry executable content.
/// Theme files are data. Nothing in a theme is evaluated as code or opened as a path.
enum ThemeSafety {
    static func checkSize(_ data: Data, file: String) throws {
        if data.count > ThemeLimits.maxDocumentBytes {
            throw ThemePersistenceError.oversizedFile(file: file, bytes: data.count)
        }
    }

    static func scan(_ value: Any) throws {
        try walk(value, path: "the document", depth: 0)
    }

    private static func walk(_ value: Any, path: String, depth: Int) throws {
        if depth > ThemeLimits.maxDepth {
            throw ThemeCodingError.invalidTheme("\(path) is nested too deeply.")
        }
        if let dictionary = value as? [String: Any] {
            if dictionary.count > ThemeLimits.maxObjectKeys {
                throw ThemeCodingError.invalidTheme("\(path) has too many fields.")
            }
            for (key, nested) in dictionary {
                let lowered = key.lowercased()
                if ThemeLimits.forbiddenKeys.contains(lowered) {
                    throw ThemeCodingError.invalidTheme("Theme files cannot contain “\(key)”. Nothing in a theme is executed.")
                }
                try walk(nested, path: "\(path).\(key)", depth: depth + 1)
            }
            return
        }
        if let array = value as? [Any] {
            if array.count > ThemeLimits.maxArrayCount {
                throw ThemeCodingError.invalidTheme("\(path) has too many items.")
            }
            for (index, nested) in array.enumerated() {
                try walk(nested, path: "\(path)[\(index)]", depth: depth + 1)
            }
            return
        }
        if let string = value as? String {
            try ThemeValidation.requireText(string, field: path, limit: ThemeLimits.maxBodyLength, allowNewlines: true)
            return
        }
        if value is NSNull || value is Bool || value is Int || value is Double || value is NSNumber {
            return
        }
        throw ThemeCodingError.invalidTheme("\(path) uses a value this theme format does not allow.")
    }
}
