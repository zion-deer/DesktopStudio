import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var terminationHandler: (() -> NSApplication.TerminateReply)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationHandler?() ?? .terminateNow
    }
}
