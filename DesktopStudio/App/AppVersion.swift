import Foundation

/// Marketing version and build number. The Xcode project is the source of truth:
/// `MARKETING_VERSION` is the semantic version and `CURRENT_PROJECT_VERSION` is the build number.
enum AppVersion {
    static let establishedMarketingVersion = "0.2.5"
    static let establishedBuildNumber = "7"

    static var marketing: String {
        bundleValue(for: "CFBundleShortVersionString") ?? establishedMarketingVersion
    }

    static var build: String {
        bundleValue(for: "CFBundleVersion") ?? establishedBuildNumber
    }

    private static func bundleValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
