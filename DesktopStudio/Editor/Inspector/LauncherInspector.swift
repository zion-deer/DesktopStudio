import SwiftUI

struct LauncherInspector: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InspectorSection(title: "Pinned") {
                if let favorites = model.selectedComponent?.settings.launcherFavorites, !favorites.isEmpty {
                    ForEach(favorites) { favorite in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(favorite.title)
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) {
                                    model.removeLauncherFavorite(favorite.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Unpin \(favorite.title)")
                            }
                            TextField("Group", text: model.launcherFavoriteBinding(favorite.id, keyPath: \.groupName))
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Group for \(favorite.title)")
                            Text(favorite.bundleIdentifier)
                                .font(.caption.monospaced())
                                .foregroundStyle(StudioPalette.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(StudioPalette.elevated, in: RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    Text("Pin applications to keep them at the top of the launcher.")
                        .font(.callout)
                        .foregroundStyle(StudioPalette.textSecondary)
                }
                Button {
                    model.chooseLauncherFavorite()
                } label: {
                    Label("Pin Application…", systemImage: "plus")
                }
                .accessibilityLabel("Pin an application")
            }

            InspectorSection(title: "Launcher") {
                InspectorSlider(
                    title: "Spacing",
                    value: spacingBinding,
                    range: 0...ThemeLimits.maxSpacing,
                    step: 1,
                    model: model
                )
                Picker("Placement", selection: placementBinding) {
                    ForEach(LauncherPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }
                .accessibilityLabel("Launcher placement")
                TextField("Shortcut key", text: keyBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Launcher shortcut key")
                Text("Modifiers: \(model.selectedComponent?.settings.launcherShortcutModifiers.joined(separator: ", ") ?? "")")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                Toggle("Command", isOn: modifierBinding("command"))
                Toggle("Option", isOn: modifierBinding("option"))
                Toggle("Shift", isOn: modifierBinding("shift"))
                Toggle("Control", isOn: modifierBinding("control"))
                Text("The shortcut is registered while a desktop experience is applied. Command-Space stays with Spotlight. Colors, type, opacity, and corner radius are in Appearance. Size is the frame.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var spacingBinding: Binding<Double> {
        Binding(
            get: { model.selectedComponent?.settings.launcherSpacing ?? LauncherCatalog.defaultSpacing },
            set: { model.setLauncherSpacing($0) }
        )
    }

    private var placementBinding: Binding<LauncherPlacement> {
        Binding(
            get: { model.selectedComponent?.settings.launcherPlacement ?? .center },
            set: { model.setLauncherPlacement($0) }
        )
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { model.selectedComponent?.settings.launcherShortcutKey ?? LauncherShortcut.defaultKey },
            set: { model.setLauncherShortcutKey($0) }
        )
    }

    private func modifierBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { model.selectedComponent?.settings.launcherShortcutModifiers.contains(name) ?? false },
            set: { model.setLauncherModifier(name, enabled: $0) }
        )
    }
}
