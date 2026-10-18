import Foundation

/// Which display a widget was last on, plus the canvas frame saved with the theme.
struct RuntimePlacementRecord: Codable, Equatable {
    var componentID: UUID
    var displayID: UInt32
    var frame: ComponentFrame
}

/// Disk record of an applied desktop experience.
///
/// The theme file remains the source of truth for component content and canvas frames.
/// This session only remembers that the experience is active, which display each widget
/// used, and the theme snapshot from the moment Apply was chosen. Restore Default
/// Experience writes that snapshot back. Stop leaves the snapshot in place but does not
/// reopen windows on the next launch.
struct DesktopExperienceSession: Codable, Equatable {
    static let currentVersion = 1

    var sessionVersion: Int
    var active: Bool
    var themeID: UUID
    var baseline: Theme
    var placements: [RuntimePlacementRecord]

    init(active: Bool, themeID: UUID, baseline: Theme, placements: [RuntimePlacementRecord]) {
        self.sessionVersion = Self.currentVersion
        self.active = active
        self.themeID = themeID
        self.baseline = baseline
        self.placements = placements
    }
}

protocol RuntimeSessionStoring: AnyObject {
    func load() -> DesktopExperienceSession?
    func save(_ session: DesktopExperienceSession)
    func clear()
}

final class MemoryRuntimeSessionStore: RuntimeSessionStoring {
    private var session: DesktopExperienceSession?

    func load() -> DesktopExperienceSession? { session }

    func save(_ session: DesktopExperienceSession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}

enum RuntimeSessionLocation {
    static func defaultFileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base
            .appendingPathComponent("Desktop Studio", isDirectory: true)
            .appendingPathComponent("Runtime", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("session.json")
    }
}

final class FileRuntimeSessionStore: RuntimeSessionStoring {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> DesktopExperienceSession? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            StudioLog.runtime.error("Could not read the desktop session: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let session = try decoder.decode(DesktopExperienceSession.self, from: data)
            guard session.sessionVersion == DesktopExperienceSession.currentVersion else {
                StudioLog.runtime.error("Ignoring desktop session version \(session.sessionVersion, privacy: .public).")
                clear()
                return nil
            }
            return session
        } catch {
            StudioLog.runtime.error("Ignoring an unreadable desktop session: \(error.localizedDescription, privacy: .public)")
            clear()
            return nil
        }
    }

    func save(_ session: DesktopExperienceSession) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            StudioLog.runtime.error("Could not save the desktop session: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            StudioLog.runtime.error("Could not remove the desktop session: \(error.localizedDescription, privacy: .public)")
        }
    }
}
