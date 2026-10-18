import AppKit
import SwiftUI

struct EditorNotice: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
}

@MainActor
final class EditorModel: ObservableObject {
    @Published private(set) var themes: [Theme]
    @Published private(set) var selectedThemeID: Theme.ID
    @Published var selectedComponentID: DesktopComponent.ID?
    @Published var isPreviewPresented = false
    @Published var showsGrid = true
    @Published private(set) var isDirty = false
    @Published var notice: EditorNotice?
    @Published var isConfirmingQuit = false
    @Published var isConfirmingThemeDelete = false
    @Published private(set) var statusText = "Ready"
    @Published private(set) var editRevision = 0
    @Published private(set) var lastApplyReport: DesktopApplyReport?

    private let store: any ThemeStoring
    private let runtime: any DesktopIntegrating
    private var savedSnapshots: [UUID: Theme]
    private var undoStack: [Theme] = []
    private var redoStack: [Theme] = []
    private var coalesceToken: String?
    private var coalesceTime: Date = .distantPast
    private var terminationReplyPending = false

    var selectedTheme: Theme {
        if let theme = themes.first(where: { $0.id == selectedThemeID }) {
            return theme
        }
        if let first = themes.first {
            return first
        }
        return SampleTheme.blank(name: "Untitled Theme")
    }

    var selectedComponent: DesktopComponent? {
        guard let selectedComponentID else { return nil }
        return selectedTheme.components.first(where: { $0.id == selectedComponentID })
    }

    var orderedComponents: [DesktopComponent] {
        selectedTheme.components.sorted { lhs, rhs in
            if lhs.frame.zIndex == rhs.frame.zIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.frame.zIndex < rhs.frame.zIndex
        }
    }

    var frontToBackComponents: [DesktopComponent] {
        Array(orderedComponents.reversed())
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var hasDirtyThemes: Bool {
        themes.contains { isThemeDirty($0.id) }
    }

    var dirtyThemeCount: Int {
        themes.filter { isThemeDirty($0.id) }.count
    }

    var quitMessage: String {
        let count = dirtyThemeCount
        if count == 1, let theme = themes.first(where: { isThemeDirty($0.id) }) {
            return "“\(theme.name)” has unsaved changes."
        }
        return "\(count) themes have unsaved changes."
    }

    init(store: any ThemeStoring, runtime: any DesktopIntegrating = UnavailableDesktopIntegration()) {
        self.store = store
        self.runtime = runtime
        themes = []
        selectedThemeID = UUID()
        savedSnapshots = [:]
        bootstrap()
    }

    static func live() -> EditorModel {
        do {
            return EditorModel(store: try ThemeStore())
        } catch {
            let model = EditorModel(store: InMemoryThemeStore(themes: []))
            model.notice = EditorNotice(
                title: "Theme storage is unavailable",
                message: error.localizedDescription
            )
            return model
        }
    }

    func isThemeDirty(_ id: UUID) -> Bool {
        guard let theme = themes.first(where: { $0.id == id }) else { return false }
        guard let snapshot = savedSnapshots[id] else { return true }
        return theme != snapshot
    }

    func toggleGrid() {
        showsGrid.toggle()
        editRevision += 1
    }

    func select(_ id: UUID?) {
        let resolved = id.flatMap { candidate in
            selectedTheme.components.contains(where: { $0.id == candidate }) ? candidate : nil
        }
        guard resolved != selectedComponentID else { return }
        endContinuousEdit()
        selectedComponentID = resolved
        editRevision += 1
    }

    func selectTheme(_ id: UUID) {
        guard id != selectedThemeID, themes.contains(where: { $0.id == id }) else { return }
        endContinuousEdit()
        selectedThemeID = id
        selectedComponentID = nil
        undoStack.removeAll()
        redoStack.removeAll()
        coalesceToken = nil
        refreshDirtyFlag()
        editRevision += 1
        statusText = "Editing “\(selectedTheme.name)”."
    }

    func themeBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<Theme, Value>,
        token: String
    ) -> Binding<Value> {
        Binding(
            get: { self.selectedTheme[keyPath: keyPath] },
            set: { newValue in
                guard self.selectedTheme[keyPath: keyPath] != newValue else { return }
                self.mutate(token: token, continuous: true) { theme in
                    theme[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func componentBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<DesktopComponent, Value>,
        fallback: Value,
        token: String
    ) -> Binding<Value> {
        Binding(
            get: { self.selectedComponent?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                guard let current = self.selectedComponent, current[keyPath: keyPath] != newValue else { return }
                let componentID = current.id
                self.mutate(token: token, continuous: true) { theme in
                    guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
                    theme.components[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func setCanvas(width: Double? = nil, height: Double? = nil) {
        mutate(token: "canvas.size", continuous: true) { theme in
            if let width {
                theme.canvas.width = min(max(width, CanvasSettings.minimumWidth), CanvasSettings.maximumWidth)
            }
            if let height {
                theme.canvas.height = min(max(height, CanvasSettings.minimumHeight), CanvasSettings.maximumHeight)
            }
            theme.components = theme.components.map { component in
                var component = component
                component.frame = component.frame.clamped(to: theme.canvas)
                return component
            }
        }
    }

    func setWallpaperStyle(_ style: WallpaperStyle) {
        mutate(token: "canvas.style", continuous: false) { theme in
            theme.canvas.style = style
        }
    }

    func setSelectedFrame(_ update: (inout ComponentFrame) -> Void) {
        guard let componentID = selectedComponentID else { return }
        mutate(token: "frame-\(componentID.uuidString)", continuous: true) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
            update(&theme.components[index].frame)
            theme.components[index].frame = theme.components[index].frame.clamped(to: theme.canvas)
        }
    }

    func setFrame(id: UUID, frame: ComponentFrame) {
        guard let current = selectedTheme.components.first(where: { $0.id == id }) else { return }
        let clamped = frame.clamped(to: selectedTheme.canvas)
        guard current.frame != clamped else { return }
        mutate(token: "frame-\(id.uuidString)", continuous: false) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == id }) else { return }
            theme.components[index].frame = clamped
        }
    }

    func addComponent(_ type: ComponentType, centeredAt center: CGPoint? = nil) {
        let index = selectedTheme.components.count
        let resolvedCenter = center ?? defaultCenter(for: type, index: index)
        var frame = ComponentFrame(
            x: resolvedCenter.x - type.defaultWidth / 2,
            y: resolvedCenter.y - type.defaultHeight / 2,
            width: type.defaultWidth,
            height: type.defaultHeight,
            zIndex: (selectedTheme.components.map(\.frame.zIndex).max() ?? -1) + 1
        )
        frame = frame.clamped(to: selectedTheme.canvas)
        let component = DesktopComponent(
            id: UUID(),
            type: type,
            name: uniqueComponentName(type.defaultName),
            frame: frame,
            appearance: ComponentAppearance.standard(for: type),
            settings: ComponentSettings.standard(for: type)
        )
        mutate(token: "add-\(component.id.uuidString)", continuous: false) { theme in
            theme.components.append(component)
        }
        selectedComponentID = component.id
        statusText = "Added \(type.libraryTitle)."
    }

    func deleteComponent(id: UUID) {
        guard selectedTheme.components.contains(where: { $0.id == id }) else { return }
        let name = selectedTheme.components.first(where: { $0.id == id })?.name ?? "Component"
        mutate(token: "delete-\(id.uuidString)", continuous: false) { theme in
            theme.components.removeAll { $0.id == id }
        }
        if selectedComponentID == id {
            selectedComponentID = nil
        }
        statusText = "Removed \(name)."
    }

    func deleteSelectedComponent() {
        guard let selectedComponentID else { return }
        deleteComponent(id: selectedComponentID)
    }

    func duplicateComponent(id: UUID) {
        guard var copy = selectedTheme.components.first(where: { $0.id == id }) else { return }
        copy.id = UUID()
        copy.name = uniqueComponentName(copy.name)
        copy.frame.x += 24
        copy.frame.y += 24
        copy.frame.zIndex = (selectedTheme.components.map(\.frame.zIndex).max() ?? 0) + 1
        copy.frame = copy.frame.clamped(to: selectedTheme.canvas)
        copy.settings.dockItems = copy.settings.dockItems.map { item in
            var item = item
            item.id = UUID()
            return item
        }
        mutate(token: "duplicate-\(copy.id.uuidString)", continuous: false) { theme in
            theme.components.append(copy)
        }
        selectedComponentID = copy.id
        statusText = "Duplicated \(copy.name)."
    }

    func duplicateSelectedComponent() {
        guard let selectedComponentID else { return }
        duplicateComponent(id: selectedComponentID)
    }

    func nudgeSelected(dx: Double, dy: Double) {
        guard let componentID = selectedComponentID else { return }
        mutate(token: "nudge-\(componentID.uuidString)", continuous: true) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
            theme.components[index].frame.x += dx
            theme.components[index].frame.y += dy
            theme.components[index].frame = theme.components[index].frame.clamped(to: theme.canvas)
        }
    }

    func bringForward(_ id: UUID) {
        reorder(id, direction: 1)
    }

    func sendBackward(_ id: UUID) {
        reorder(id, direction: -1)
    }

    func resetSelectedAppearance() {
        guard let component = selectedComponent else { return }
        mutate(token: "reset-appearance-\(component.id.uuidString)", continuous: false) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == component.id }) else { return }
            theme.components[index].appearance = ComponentAppearance.standard(for: component.type)
        }
        statusText = "Reset appearance."
    }

    func addDockItem() {
        guard let componentID = selectedComponentID else { return }
        mutate(token: "dock-add-\(UUID().uuidString)", continuous: false) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
            theme.components[index].settings.dockItems.append(
                DockItem(id: UUID(), title: "App", symbolName: "app.fill")
            )
        }
    }

    func deleteDockItem(_ itemID: UUID) {
        guard let componentID = selectedComponentID else { return }
        mutate(token: "dock-delete-\(itemID.uuidString)", continuous: false) { theme in
            guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
            theme.components[index].settings.dockItems.removeAll { $0.id == itemID }
        }
    }

    func moveDockItem(_ itemID: UUID, direction: Int) {
        guard let componentID = selectedComponentID else { return }
        mutate(token: "dock-move-\(itemID.uuidString)-\(direction)", continuous: false) { theme in
            guard let componentIndex = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
            var items = theme.components[componentIndex].settings.dockItems
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
            let target = index + direction
            guard items.indices.contains(target) else { return }
            items.swapAt(index, target)
            theme.components[componentIndex].settings.dockItems = items
        }
    }

    func dockItemBinding(_ itemID: UUID, keyPath: WritableKeyPath<DockItem, String>) -> Binding<String> {
        Binding(
            get: {
                self.selectedComponent?.settings.dockItems.first(where: { $0.id == itemID })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard let componentID = self.selectedComponentID else { return }
                self.mutate(token: "dock-\(keyPath)-\(itemID.uuidString)", continuous: true) { theme in
                    guard
                        let componentIndex = theme.components.firstIndex(where: { $0.id == componentID }),
                        let itemIndex = theme.components[componentIndex].settings.dockItems.firstIndex(where: { $0.id == itemID })
                    else { return }
                    theme.components[componentIndex].settings.dockItems[itemIndex][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func newTheme() {
        let theme = SampleTheme.blank(name: uniqueThemeName("Untitled Theme"))
        do {
            try store.save(theme)
            themes.append(theme)
            themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            savedSnapshots[theme.id] = theme
            selectTheme(theme.id)
            statusText = "Created “\(theme.name)”."
        } catch {
            present(error)
        }
    }

    func duplicateSelectedTheme() {
        var copy = selectedTheme
        copy.id = UUID()
        copy.name = uniqueThemeName(copy.name + " Copy")
        let now = Date()
        copy.createdAt = now
        copy.updatedAt = now
        copy.components = copy.components.map { component in
            var component = component
            component.id = UUID()
            component.settings.dockItems = component.settings.dockItems.map { item in
                var item = item
                item.id = UUID()
                return item
            }
            return component
        }
        do {
            try store.save(copy)
            themes.append(copy)
            themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            savedSnapshots[copy.id] = copy
            selectTheme(copy.id)
            statusText = "Duplicated as “\(copy.name)”."
        } catch {
            present(error)
        }
    }

    func saveSelectedTheme() {
        guard isDirty else {
            statusText = "Already saved."
            return
        }
        do {
            try persist(selectedThemeID)
            statusText = "Saved “\(selectedTheme.name)”."
            announce(statusText)
        } catch {
            present(error)
        }
    }

    func saveAllDirtyAndReport() {
        let count = dirtyThemeCount
        do {
            try saveAllDirty()
            statusText = count == 0 ? "Already saved." : "Saved \(count) \(count == 1 ? "theme" : "themes")."
            announce(statusText)
        } catch {
            present(error)
        }
    }

    func revertSelectedTheme() {
        guard let snapshot = savedSnapshots[selectedThemeID] else {
            statusText = "This theme has no saved copy to restore."
            return
        }
        guard let index = themes.firstIndex(where: { $0.id == selectedThemeID }) else { return }
        themes[index] = snapshot
        selectedComponentID = nil
        undoStack.removeAll()
        redoStack.removeAll()
        coalesceToken = nil
        refreshDirtyFlag()
        editRevision += 1
        statusText = "Reverted to the saved theme."
    }

    func importTheme() {
        guard let url = ThemeFilePanel.chooseImportURL() else { return }
        do {
            let data = try ThemeFileAccess.read(url)
            var theme = try ThemeCoding.decode(data, file: url.lastPathComponent).theme
            theme.id = UUID()
            theme.name = uniqueThemeName(theme.name)
            let now = Date()
            theme.createdAt = now
            theme.updatedAt = now
            theme.components = theme.components.map { component in
                var component = component
                component.id = UUID()
                component.settings.dockItems = component.settings.dockItems.map { item in
                    var item = item
                    item.id = UUID()
                    return item
                }
                return component
            }
            try store.save(theme)
            themes.append(theme)
            themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            savedSnapshots[theme.id] = theme
            selectTheme(theme.id)
            statusText = "Imported “\(theme.name)”."
        } catch {
            present(error)
        }
    }

    func exportSelectedTheme() {
        guard let url = ThemeFilePanel.chooseExportURL(suggestedName: exportFilename(for: selectedTheme.name)) else { return }
        do {
            var theme = selectedTheme
            theme.updatedAt = Date()
            try theme.validate()
            let data = try ThemeCoding.encode(theme)
            try ThemeFileAccess.write(data, to: url)
            statusText = "Exported “\(theme.name)”."
            announce(statusText)
        } catch {
            present(error)
        }
    }

    func performDeleteSelectedTheme() {
        let deletedID = selectedThemeID
        let name = selectedTheme.name
        do {
            try store.delete(id: deletedID)
        } catch {
            present(error)
            return
        }
        themes.removeAll { $0.id == deletedID }
        savedSnapshots[deletedID] = nil
        if themes.isEmpty {
            let blank = SampleTheme.blank(name: "Untitled Theme")
            do {
                try store.save(blank)
                themes = [blank]
                savedSnapshots = [blank.id: blank]
            } catch {
                let sample = SampleTheme.make()
                themes = [sample]
                savedSnapshots = [:]
                present(error)
            }
        }
        undoStack.removeAll()
        redoStack.removeAll()
        coalesceToken = nil
        if let first = themes.first(where: { $0.id != deletedID }) ?? themes.first {
            selectedThemeID = first.id
        }
        selectedComponentID = nil
        refreshDirtyFlag()
        editRevision += 1
        statusText = "Deleted “\(name)”."
    }

    func applySelectedTheme() {
        let report = runtime.apply(theme: selectedTheme)
        lastApplyReport = report
        notice = EditorNotice(title: report.title, message: report.message)
        statusText = report.title
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        guard previous.id == selectedThemeID else {
            undoStack.removeAll()
            return
        }
        redoStack.append(selectedTheme)
        replaceSelected(previous)
        coalesceToken = nil
        refreshDirtyFlag()
        editRevision += 1
        statusText = "Undid the last change."
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        guard next.id == selectedThemeID else {
            redoStack.removeAll()
            return
        }
        undoStack.append(selectedTheme)
        replaceSelected(next)
        coalesceToken = nil
        refreshDirtyFlag()
        editRevision += 1
        statusText = "Redid the last change."
    }

    func endContinuousEdit() {
        if let last = undoStack.last, last == selectedTheme {
            undoStack.removeLast()
        }
        coalesceToken = nil
        editRevision += 1
    }

    func prepareForTermination() -> NSApplication.TerminateReply {
        guard hasDirtyThemes else { return .terminateNow }
        if terminationReplyPending {
            return .terminateLater
        }
        terminationReplyPending = true
        isConfirmingQuit = true
        return .terminateLater
    }

    func quitAndSave() {
        do {
            try saveAllDirty()
            finishTermination(shouldTerminate: true)
        } catch {
            finishTermination(shouldTerminate: false)
            present(error)
        }
    }

    func quitWithoutSaving() {
        finishTermination(shouldTerminate: true)
    }

    func cancelQuit() {
        finishTermination(shouldTerminate: false)
    }

    private func bootstrap() {
        do {
            let library = try store.loadLibrary()
            var loaded = library.themes
            if loaded.isEmpty {
                let sample = try loadBundledSample()
                try store.save(sample)
                loaded = [sample]
            }
            themes = loaded
            savedSnapshots = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            selectedThemeID = loaded[0].id
            if !library.issues.isEmpty {
                notice = EditorNotice(
                    title: "Some themes could not be opened",
                    message: library.issues.map(\.message).joined(separator: "\n\n")
                )
            }
            statusText = "Editing “\(selectedTheme.name)”."
        } catch {
            let sample = SampleTheme.make()
            themes = [sample]
            selectedThemeID = sample.id
            savedSnapshots = [:]
            notice = EditorNotice(
                title: "Opened a temporary sample",
                message: error.localizedDescription
            )
            statusText = "Editing a temporary copy of Night Harbor."
            StudioLog.persistence.error("Theme library failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshDirtyFlag()
    }

    private func loadBundledSample() throws -> Theme {
        do {
            let data = try ThemeResources.sampleThemeData()
            return try ThemeCoding.decode(data, file: "SampleTheme.json").theme
        } catch {
            StudioLog.persistence.error("Sample JSON failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func mutate(token: String, continuous: Bool, _ body: (inout Theme) -> Void) {
        guard let themeIndex = themes.firstIndex(where: { $0.id == selectedThemeID }) else { return }
        var theme = themes[themeIndex]
        body(&theme)
        guard theme != themes[themeIndex] else { return }

        if continuous {
            let now = Date()
            if coalesceToken != token || now.timeIntervalSince(coalesceTime) > 0.45 {
                pushUndo()
                coalesceToken = token
            }
            coalesceTime = now
        } else {
            pushUndo()
            coalesceToken = nil
        }

        themes[themeIndex] = theme
        redoStack.removeAll()
        refreshDirtyFlag()
        editRevision += 1
    }

    private func pushUndo() {
        if undoStack.last == selectedTheme { return }
        undoStack.append(selectedTheme)
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
    }

    private func replaceSelected(_ theme: Theme) {
        guard let index = themes.firstIndex(where: { $0.id == selectedThemeID }) else { return }
        themes[index] = theme
        if let selectedComponentID, !theme.components.contains(where: { $0.id == selectedComponentID }) {
            self.selectedComponentID = nil
        }
    }

    private func reorder(_ id: UUID, direction: Int) {
        let ordered = orderedComponents
        guard let index = ordered.firstIndex(where: { $0.id == id }) else { return }
        let neighborIndex = index + direction
        guard ordered.indices.contains(neighborIndex) else { return }
        let neighborID = ordered[neighborIndex].id
        mutate(token: "z-\(id.uuidString)-\(neighborID.uuidString)", continuous: false) { theme in
            guard
                let currentIndex = theme.components.firstIndex(where: { $0.id == id }),
                let otherIndex = theme.components.firstIndex(where: { $0.id == neighborID })
            else { return }
            let currentZ = theme.components[currentIndex].frame.zIndex
            let otherZ = theme.components[otherIndex].frame.zIndex
            theme.components[currentIndex].frame.zIndex = otherZ
            theme.components[otherIndex].frame.zIndex = currentZ
            if theme.components[currentIndex].frame.zIndex == theme.components[otherIndex].frame.zIndex {
                theme.components[currentIndex].frame.zIndex = otherZ + direction
            }
        }
    }

    private func persist(_ id: UUID) throws {
        guard let index = themes.firstIndex(where: { $0.id == id }) else { return }
        var theme = themes[index]
        theme.updatedAt = Date()
        try store.save(theme)
        themes[index] = theme
        savedSnapshots[id] = theme
        refreshDirtyFlag()
        editRevision += 1
    }

    private func saveAllDirty() throws {
        let ids = themes.map(\.id).filter { isThemeDirty($0) }
        for id in ids {
            try persist(id)
        }
    }

    private func refreshDirtyFlag() {
        let dirty = isThemeDirty(selectedThemeID)
        if dirty != isDirty {
            isDirty = dirty
        }
    }

    private func present(_ error: Error) {
        notice = EditorNotice(title: "Something went wrong", message: error.localizedDescription)
        statusText = error.localizedDescription
        StudioLog.editor.error("\(error.localizedDescription, privacy: .public)")
    }

    private func finishTermination(shouldTerminate: Bool) {
        guard terminationReplyPending else { return }
        terminationReplyPending = false
        isConfirmingQuit = false
        NSApp.reply(toApplicationShouldTerminate: shouldTerminate)
    }

    private func defaultCenter(for type: ComponentType, index: Int) -> CGPoint {
        let canvas = selectedTheme.canvas
        switch type {
        case .dock:
            return CGPoint(x: canvas.width / 2, y: canvas.height - type.defaultHeight / 2 - 36)
        default:
            let stagger = Double(index % 6) * 24
            return CGPoint(x: canvas.width / 2 + stagger, y: canvas.height * 0.42 + stagger)
        }
    }

    private func uniqueComponentName(_ base: String) -> String {
        uniqueName(base, existing: Set(selectedTheme.components.map(\.name)))
    }

    private func uniqueThemeName(_ base: String) -> String {
        uniqueName(base, existing: Set(themes.map(\.name)))
    }

    private func uniqueName(_ base: String, existing: Set<String>) -> String {
        if !existing.contains(base) { return base }
        var number = 2
        while existing.contains("\(base) \(number)") {
            number += 1
        }
        return "\(base) \(number)"
    }

    private func exportFilename(for name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "Theme" : cleaned) + ".json"
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
