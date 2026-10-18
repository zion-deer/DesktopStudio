import Foundation

/// Rules shared by the app and the release workflow's checks.
/// Sparkle compares `CFBundleVersion` (the build number), not the marketing version.
enum ReleaseRules {
    static let minimumSystemVersion = "14.0"
    static let appcastFileName = "appcast.xml"

    static func marketingVersion(fromTag tag: String) -> String? {
        guard tag.hasPrefix("v"), tag.count > 1 else { return nil }
        let version = String(tag.dropFirst())
        return isSemanticVersion(version) ? version : nil
    }

    static func isSemanticVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy(isUnpaddedNumber)
    }

    static func isBuildNumber(_ value: String) -> Bool {
        isUnpaddedNumber(Substring(value)) && Int(value) != nil
    }

    static func buildIsNewer(_ candidate: String, than previous: [String]) -> Bool {
        guard let candidateNumber = Int(candidate) else { return false }
        let earlier = previous.compactMap(Int.init)
        return earlier.allSatisfy { candidateNumber > $0 }
    }

    static func feedConfigurationError(urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("$(") {
            return "The update feed URL is not set."
        }
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else {
            return "The update feed URL must be an https address."
        }
        if url.user != nil || url.password != nil {
            return "The update feed URL must not contain credentials."
        }
        if trimmed.lowercased().contains("example.com")
            || trimmed.lowercased().contains("example.org")
            || trimmed.lowercased().contains("yourcompany")
            || trimmed.lowercased().contains("placeholder")
            || trimmed.lowercased().contains("changeme")
            || trimmed.contains("<owner>")
            || trimmed.contains("<repo>") {
            return "The update feed URL is still a placeholder."
        }
        guard url.lastPathComponent == appcastFileName else {
            return "The update feed URL must end with \(appcastFileName)."
        }
        return nil
    }

    static func publicKeyError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("$(") {
            return "The Sparkle public key is not set."
        }
        guard let data = Data(base64Encoded: trimmed), data.count == 32 else {
            return "The Sparkle public key must be the 32-byte Ed25519 key from generate_keys, encoded as base64."
        }
        return nil
    }

    static func enclosureError(urlString: String, shortVersion: String, edSignature: String, length: Int) -> String? {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
            return "The update archive URL must be https."
        }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let download = parts.firstIndex(of: "download"),
              download + 1 < parts.count,
              parts[download + 1] == "v\(shortVersion)" else {
            return "The update archive URL must be the versioned GitHub release download for v\(shortVersion)."
        }
        if parts.contains("latest") {
            return "The update archive URL must not use a mutable latest download link."
        }
        guard url.pathExtension.lowercased() == "zip" else {
            return "The update archive must be a zip."
        }
        let signature = edSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !signature.isEmpty, Data(base64Encoded: signature) != nil else {
            return "The update archive is missing a Sparkle EdDSA signature."
        }
        guard length > 0 else {
            return "The update archive length must be greater than zero."
        }
        return nil
    }

    /// Sparkle replaces the application bundle. Theme files live outside that bundle.
    static func themesStayOutsideTheApp(appBundle: URL, themesDirectory: URL) -> Bool {
        let bundle = appBundle.standardizedFileURL.path
        let themes = themesDirectory.standardizedFileURL.path
        let outsideBundle = themes != bundle && !themes.hasPrefix(bundle + "/")
        return outsideBundle && themes.contains("Application Support/Desktop Studio/Themes")
    }

    private static func isUnpaddedNumber(_ part: Substring) -> Bool {
        guard !part.isEmpty, part.allSatisfy(\.isNumber) else { return false }
        return part.count == 1 || !part.hasPrefix("0")
    }
}
