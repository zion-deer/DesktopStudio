import SwiftUI

struct EditorRootView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        NavigationSplitView {
            ComponentLibraryView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 256, max: 320)
        } content: {
            DesktopCanvasView()
        } detail: {
            PropertiesInspectorView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 312, max: 400)
        }
        .navigationTitle("Desktop Studio")
        .navigationSplitViewStyle(.balanced)
        .toolbar { toolbar }
        .toolbarBackground(StudioPalette.sidebar, for: .windowToolbar)
        .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
        .preferredColorScheme(.dark)
        .tint(StudioPalette.accent)
        .frame(minWidth: 1100, minHeight: 720)
        .background(StudioPalette.sidebar)
        .focusedSceneValue(\.editorModel, model)
        .focusedSceneValue(\.editorRevision, model.editRevision)
        .accessibilityIdentifier(StudioAccessibilityID.editorRoot)
        .sheet(isPresented: $model.isPreviewPresented) {
            ThemePreviewView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isGalleryPresented) {
            ThemeGalleryView()
                .environmentObject(model)
        }
        .alert(
            "Reset \(model.selectedTheme.name)?",
            isPresented: $model.isConfirmingBuiltInReset
        ) {
            Button("Reset Theme", role: .destructive) {
                model.resetBuiltInContent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wallpaper, components, and theme style return to the built-in original. You can undo this until you quit.")
        }
        .alert(
            model.notice?.title ?? "Notice",
            isPresented: noticePresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.notice?.message ?? "")
        }
        .alert(
            "Delete \(model.selectedTheme.name)?",
            isPresented: $model.isConfirmingThemeDelete
        ) {
            Button("Delete Theme", role: .destructive) {
                model.performDeleteSelectedTheme()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The theme file is removed from your library. This cannot be undone.")
        }
        .confirmationDialog(
            "Save changes before quitting?",
            isPresented: quitPresented,
            titleVisibility: .visible
        ) {
            Button("Save") { model.quitAndSave() }
            Button("Don't Save", role: .destructive) { model.quitWithoutSaving() }
            Button("Cancel", role: .cancel) { model.cancelQuit() }
        } message: {
            Text(model.quitMessage)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 10) {
                Picker("Theme", selection: themeSelection) {
                    ForEach(model.themes) { theme in
                        Text(model.isThemeDirty(theme.id) ? "\(theme.name) •" : theme.name)
                            .tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 180)
                .accessibilityIdentifier(StudioAccessibilityID.themePicker)
                .accessibilityLabel("Theme")
                .help("Choose a theme")

                if model.isDirty {
                    Text("Edited")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioPalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(StudioPalette.accent.opacity(0.16), in: Capsule())
                        .accessibilityLabel("Unsaved changes")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.saveSelectedTheme()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!model.isDirty)
            .accessibilityIdentifier(StudioAccessibilityID.saveButton)
            .accessibilityLabel("Save theme")
            .help("Save the selected theme as JSON")

            Button {
                model.isGalleryPresented = true
            } label: {
                Label("Themes", systemImage: "rectangle.grid.2x2")
            }
            .accessibilityLabel("Theme gallery")
            .help("Create, rename, duplicate, import, and export themes.")

            Button {
                model.isPreviewPresented = true
            } label: {
                Label("Preview", systemImage: "play.rectangle")
            }
            .accessibilityIdentifier(StudioAccessibilityID.previewButton)
            .accessibilityLabel("Preview theme")
            .accessibilityHint("Shows the desktop design without changing your Mac.")
            .help("Preview this theme. Your desktop will not change.")

            Button {
                model.applySelectedTheme()
            } label: {
                Label("Apply", systemImage: "desktopcomputer")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(StudioAccessibilityID.applyButton)
            .accessibilityLabel("Apply theme")
            .accessibilityHint("Reports whether the theme can be applied. This version does not change the Mac desktop.")
            .help("Apply is not connected to the desktop yet.")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(model.statusText)
                .lineLimit(1)
            Spacer()
            Text("The canvas is a preview. Your Mac desktop is unchanged.")
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(StudioPalette.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    private var themeSelection: Binding<UUID> {
        Binding(
            get: { model.selectedThemeID },
            set: { model.selectTheme($0) }
        )
    }

    private var noticePresented: Binding<Bool> {
        Binding(
            get: { model.notice != nil },
            set: { isPresented in
                if !isPresented {
                    model.notice = nil
                }
            }
        )
    }

    private var quitPresented: Binding<Bool> {
        Binding(
            get: { model.isConfirmingQuit },
            set: { isPresented in
                if !isPresented, model.isConfirmingQuit {
                    model.cancelQuit()
                }
            }
        )
    }
}

#Preview("Editor") {
    EditorRootView()
        .environmentObject(EditorModel(store: InMemoryThemeStore(themes: [SampleTheme.make()])))
        .frame(width: 1360, height: 860)
}
