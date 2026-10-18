import Foundation

/// Turns a Sparkle or network failure into a sentence that says the installed app was left alone.
enum UpdateFailureCopy {
    static func noUpdate(_ error: Error) -> String {
        let nsError = error as NSError
        if let reason = nsError.userInfo["SPUNoUpdateFoundReasonKey"] {
            let description = String(describing: reason)
            if description.contains("system") || description.localizedCaseInsensitiveContains("os") {
                return "The newest release requires a newer version of macOS than this Mac. Desktop Studio was not replaced."
            }
        }
        if nsError.localizedDescription.localizedCaseInsensitiveContains("macOS")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("operating system") {
            return "\(nsError.localizedDescription) Desktop Studio was not replaced."
        }
        return "This copy is already the newest published release."
    }

    static func failed(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Desktop Studio could not reach the update feed. The network may be offline, or the release server did not respond. The installed copy was not changed."
        }
        let description = nsError.localizedDescription
        if description.localizedCaseInsensitiveContains("signature")
            || description.localizedCaseInsensitiveContains("EdDSA")
            || description.localizedCaseInsensitiveContains("not valid") {
            return "The update was rejected because its Sparkle signature did not match. Nothing was installed. \(description)"
        }
        if description.localizedCaseInsensitiveContains("not found")
            || description.localizedCaseInsensitiveContains("404")
            || description.localizedCaseInsensitiveContains("appcast") {
            return "The update feed is missing or has no usable release. Desktop Studio was not replaced. \(description)"
        }
        return "The update did not finish. Desktop Studio was not replaced. \(description)"
    }
}
