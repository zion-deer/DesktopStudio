import SwiftUI

struct ThemeGalleryView: View {
    @EnvironmentObject private var model: EditorModel

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Themes")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Previews use the saved layout. They do not change your Mac desktop.")
                        .font(.callout)
                        .foregroundStyle(StudioPalette.textSecondary)
                }
                Spacer()
                Button("Done") { model.isGalleryPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close themes")
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(model.themes) { theme in
                        ThemeGalleryCard(theme: theme, isSelected: theme.id == model.selectedThemeID) {
                            model.selectTheme(theme.id)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            TextField("Theme name", text: model.themeBinding(\.name, token: "gallery.name"))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Theme name")
            HStack {
                Button("New Theme") { model.newTheme() }
                    .accessibilityLabel("New theme")
                Menu("Add Built-in") {
                    ForEach(BuiltInTheme.allCases) { preset in
                        Button(preset.title) { model.addBuiltIn(preset) }
                    }
                }
                .accessibilityLabel("Add built-in theme")
                Button("Duplicate") { model.duplicateSelectedTheme() }
                    .accessibilityLabel("Duplicate theme")
                Button("Import…") { model.importTheme() }
                    .accessibilityLabel("Import theme")
                Button("Export…") { model.exportSelectedTheme() }
                    .accessibilityLabel("Export theme")
                Button("Delete…", role: .destructive) { model.isConfirmingThemeDelete = true }
                    .accessibilityLabel("Delete theme")
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 640)
        .background(StudioPalette.stage)
        .preferredColorScheme(.dark)
    }
}

private struct ThemeGalleryCard: View {
    @EnvironmentObject private var model: EditorModel
    var theme: Theme
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8) {
                DesktopCanvasView(themeOverride: theme, isInteractive: false)
                    .frame(height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HStack {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundStyle(StudioPalette.textPrimary)
                        .lineLimit(1)
                    if model.isThemeDirty(theme.id) {
                        Text("Edited")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StudioPalette.accent)
                    }
                    Spacer()
                    Text("\(theme.components.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(StudioPalette.textTertiary)
                        .accessibilityLabel("\(theme.components.count) components")
                }
                Text(BuiltInTheme.matching(id: theme.id) == nil ? "Custom" : "Built-in")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
            }
            .padding(10)
            .background(StudioPalette.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? StudioPalette.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name), \(theme.components.count) components")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this theme")
    }
}
