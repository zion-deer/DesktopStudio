import Combine
import Sparkle

/// Owns Sparkle's standard updater for the life of the app.
///
/// Info.plist supplies the feed URL, public key, and the daily check interval.
/// This object only changes `automaticallyChecksForUpdates` after the user toggles it.
final class UpdateCenter: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var statusText: String
    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var lastCheckDescription = "No check yet."

    private let publication: UpdatePublication
    private var controller: SPUStandardUpdaterController?
    private var cancellables = Set<AnyCancellable>()
    private var sawValidUpdate = false

    override init() {
        let publication = UpdatePublication.current
        self.publication = publication
        if publication.isConfigured {
            statusText = "Desktop Studio looks for a newer signed release about once a day."
            automaticallyChecksForUpdates = true
        } else {
            statusText = publication.unavailableReason
            automaticallyChecksForUpdates = false
        }
        super.init()
        guard publication.isConfigured else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        refreshLastCheck(controller.updater.lastUpdateCheckDate)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
            .store(in: &cancellables)
    }

    var isConfigured: Bool { publication.isConfigured }

    func checkForUpdates() {
        guard let controller else {
            statusText = publication.unavailableReason
            return
        }
        sawValidUpdate = false
        statusText = "Checking for updates…"
        controller.checkForUpdates(nil)
    }

    func userChangedAutomaticChecks(to enabled: Bool) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        statusText = enabled
            ? "Automatic checks are on. Desktop Studio looks for a release about once a day."
            : "Automatic checks are off. Use Check for Updates when you want to look for a release."
    }

    private func refreshLastCheck(_ date: Date?) {
        guard let date else {
            lastCheckDescription = "No check yet."
            return
        }
        lastCheckDescription = "Last check \(date.formatted(date: .abbreviated, time: .shortened))."
    }
}

extension UpdateCenter: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        sawValidUpdate = true
        let version = item.displayVersionString
        statusText = "Version \(version) is available. Sparkle is asking whether to install the signed update."
        refreshLastCheck(updater.lastUpdateCheckDate)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        statusText = UpdateFailureCopy.noUpdate(error)
        refreshLastCheck(updater.lastUpdateCheckDate)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        statusText = UpdateFailureCopy.failed(error)
        refreshLastCheck(updater.lastUpdateCheckDate)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        statusText = UpdateFailureCopy.failed(error)
        refreshLastCheck(updater.lastUpdateCheckDate)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        _ = updateCheck
        refreshLastCheck(updater.lastUpdateCheckDate)
        if let error {
            let description = error.localizedDescription.lowercased()
            if description.contains("latest") || description.contains("up to date") || description.contains("no new") {
                statusText = UpdateFailureCopy.noUpdate(error)
            } else {
                statusText = UpdateFailureCopy.failed(error)
            }
            return
        }
        if !sawValidUpdate {
            statusText = "This copy is already the newest published release."
        }
    }
}
