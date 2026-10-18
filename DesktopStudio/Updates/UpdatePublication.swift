import Foundation

/// Values baked into a build from `UpdatePublication.xcconfig` or the release workflow.
struct UpdatePublication: Equatable {
    var feedURL: String
    var publicKey: String

    static var current: UpdatePublication {
        UpdatePublication(
            feedURL: bundleValue(for: "SUFeedURL"),
            publicKey: bundleValue(for: "SUPublicEDKey")
        )
    }

    var isConfigured: Bool {
        configurationError == nil
    }

    var configurationError: String? {
        if let feedError = ReleaseRules.feedConfigurationError(urlString: feedURL) {
            return feedError
        }
        return ReleaseRules.publicKeyError(publicKey)
    }

    var unavailableReason: String {
        if let configurationError {
            return "\(configurationError) Desktop Studio will keep running this copy. Themes and settings are not changed."
        }
        return "Automatic updates are unavailable."
    }

    private static func bundleValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
