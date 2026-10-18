import SwiftUI

@main
struct DesktopStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: EditorModel

    init() {
        _model = StateObject(wrappedValue: EditorModel.live())
    }

    var body: some Scene {
        WindowGroup {
            EditorRootView()
                .environmentObject(model)
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
        }
    }
}
