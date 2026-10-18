import SwiftUI

struct UpdateSettingsView: View {
    @EnvironmentObject private var updates: UpdateCenter

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text("\(AppVersion.marketing) (\(AppVersion.build))")
                }
                LabeledContent("Checks") {
                    Text(updates.lastCheckDescription)
                }
                Text(updates.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle("Check for updates automatically", isOn: automaticChecks)
                    .disabled(!updates.isConfigured)
                Text("A check runs about once a day while the app is open. Installation still asks you to confirm, unless you turn on automatic installation in Sparkle’s update window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            Section {
                Text("Themes, the desktop session, and other settings stay in Application Support. Sparkle replaces only the Desktop Studio app. An update that fails its signature, the network, or the macOS version check leaves this copy installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding(20)
        .navigationTitle("Updates")
    }

    private var automaticChecks: Binding<Bool> {
        Binding(
            get: { updates.automaticallyChecksForUpdates },
            set: { updates.userChangedAutomaticChecks(to: $0) }
        )
    }
}
