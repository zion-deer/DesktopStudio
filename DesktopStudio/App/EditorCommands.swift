import SwiftUI

struct EditorModelFocusKey: FocusedValueKey {
    typealias Value = EditorModel
}

struct EditorRevisionFocusKey: FocusedValueKey {
    typealias Value = Int
}

extension FocusedValues {
    var editorModel: EditorModel? {
        get { self[EditorModelFocusKey.self] }
        set { self[EditorModelFocusKey.self] = newValue }
    }

    var editorRevision: Int? {
        get { self[EditorRevisionFocusKey.self] }
        set { self[EditorRevisionFocusKey.self] = newValue }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorModel) private var model
    @FocusedValue(\.editorRevision) private var revision

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Theme") { model?.newTheme() }
                .keyboardShortcut("n")
                .disabled(!actionsEnabled)
            Button("New Windows Inspired Theme") { model?.addBuiltIn(.windows) }
                .disabled(!actionsEnabled)
            Button("New Minimal Dark Theme") { model?.addBuiltIn(.minimalDark) }
                .disabled(!actionsEnabled)
            Button("New Futuristic Theme") { model?.addBuiltIn(.futuristic) }
                .disabled(!actionsEnabled)
            Button("Theme Gallery") { model?.isGalleryPresented = true }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!actionsEnabled)
            Button("Duplicate Theme") { model?.duplicateSelectedTheme() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!actionsEnabled)
            Button("Import Theme…") { model?.importTheme() }
                .disabled(!actionsEnabled)
            Button("Export Theme…") { model?.exportSelectedTheme() }
                .disabled(!actionsEnabled)
            Divider()
            Button("Delete Theme…") { model?.isConfirmingThemeDelete = true }
                .disabled(!actionsEnabled)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Theme") { model?.saveSelectedTheme() }
                .keyboardShortcut("s")
                .disabled(model?.isDirty != true)
            Button("Save All Themes") { model?.saveAllDirtyAndReport() }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(model?.hasDirtyThemes != true)
            Button("Revert Theme") { model?.revertSelectedTheme() }
                .disabled(model?.isDirty != true)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model?.undo() }
                .keyboardShortcut("z")
                .disabled(model?.canUndo != true)
            Button("Redo") { model?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(model?.canRedo != true)
        }

        CommandGroup(after: .pasteboard) {
            Button("Duplicate Component") { model?.duplicateSelectedComponent() }
                .keyboardShortcut("d")
                .disabled(model?.selectedComponentID == nil)
            Button("Delete Component") { model?.deleteSelectedComponent() }
                .keyboardShortcut(.delete)
                .disabled(model?.selectedComponentID == nil)
        }

        CommandMenu("Theme") {
            Button("Preview") { model?.isPreviewPresented = true }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!actionsEnabled)
            Button("Apply…") { model?.applySelectedTheme() }
                .disabled(!actionsEnabled)
            Button("Open Launcher") { model?.toggleLauncher() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(model?.isDesktopExperienceActive != true || !menuRefresh)
            Button("Stop Desktop Experience") { model?.stopDesktopExperience() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(model?.isDesktopExperienceActive != true || !menuRefresh)
            Button("Restore Default Experience") { model?.restoreDefaultDesktop() }
                .disabled(!actionsEnabled)
            Divider()
            Button("Reset Theme Style") { model?.resetGlobalStyle() }
                .disabled(!actionsEnabled)
            Button("Reset Built-in Theme…") { model?.isConfirmingBuiltInReset = true }
                .disabled(model?.selectedBuiltIn == nil)
        }

        CommandMenu("View") {
            Button("Zoom In") { model?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!actionsEnabled)
            Button("Zoom Out") { model?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!actionsEnabled)
            Button("Actual Size") { model?.resetCanvasZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!actionsEnabled)
            Divider()
            Button(model?.showsGrid == true ? "Hide Grid" : "Show Grid") {
                model?.toggleGrid()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!actionsEnabled)
        }
    }

    /// Reads the focused revision so menu enablement refreshes after edits.
    private var actionsEnabled: Bool {
        model != nil && menuRefresh
    }

    private var menuRefresh: Bool {
        (revision ?? 0) >= 0
    }
}
