import SwiftUI

@main
struct DesktopStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: EditorModel
    @StateObject private var updates = UpdateCenter()

    init() {
        _model = StateObject(wrappedValue: EditorModel.live())
    }

    var body: some Scene {
        WindowGroup {
            EditorRootView()
                .environmentObject(model)
                .environmentObject(updates)
                .onAppear {
                    appDelegate.terminationHandler = { [weak model] in
                        MainActor.assumeIsolated {
                            model?.prepareForTermination() ?? .terminateNow
                        }
                    }
                }
        }
        .defaultSize(width: 1360, height: 860)
        .windowToolbarStyle(.unified)
        .commands {
            EditorCommands()
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }
        }

        Settings {
            UpdateSettingsView()
                .environmentObject(updates)
        }
    }
}
