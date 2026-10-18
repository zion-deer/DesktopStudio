import AppKit
import SwiftUI

extension Notification.Name {
    static let desktopLauncherDidOpen = Notification.Name("desktopLauncherDidOpen")
}

struct LauncherWidgetView: View {
    @ObservedObject var model: WidgetModel
    var onLaunch: (String) -> Void
    var onDismiss: () -> Void
    var onStop: () -> Void = {}
    @State private var query = ""
    @State private var selection = 0
    @State private var applications: [InstalledApplication] = []
    @State private var warnings: [String] = []
    @FocusState private var searchFocused: Bool

    private var appearance: ComponentAppearance {
        model.component.resolvedAppearance(in: model.theme)
    }

    private var rows: [LauncherListRow] {
        LauncherList.rows(
            favorites: model.component.settings.launcherFavorites,
            applications: applications,
            query: query
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: model.component.settings.launcherSpacing) {
            HStack {
                Text("Launcher")
                    .font(.system(size: max(13, appearance.fontSize), weight: .semibold, design: appearance.fontDesign.fontDesign))
                Spacer()
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close launcher")
                Button("Stop Desktop Experience") { onStop() }
            }
            TextField("Search applications", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .accessibilityLabel("Search applications")
                .onSubmit { activateSelection() }
                .onKeyPress(.downArrow) {
                    move(1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    move(-1)
                    return .handled
                }
            List(selection: selectionBinding) {
                ForEach(rows) { row in
                    rowView(row)
                        .tag(row.index)
                }
            }
            .listStyle(.plain)
            .accessibilityLabel("Applications")
            Text(hint)
                .font(.caption)
                .foregroundStyle(appearance.foreground.color.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(appearance.foreground.color)
        .background(appearance.background.color)
        .opacity(appearance.opacity)
        .onAppear {
            reloadCatalog()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .desktopLauncherDidOpen)) { note in
            guard note.object as? String == model.component.id.uuidString else { return }
            reloadCatalog()
            searchFocused = true
            selection = 0
        }
        .onKeyPress(.downArrow) {
            move(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            move(-1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
            return .handled
        }
        .onChange(of: query) { _, _ in
            selection = 0
        }
    }

    private var selectionBinding: Binding<Int?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? 0 }
        )
    }

    private var hint: String {
        if rows.isEmpty {
            return warnings.isEmpty
                ? "No matching applications in the folders Desktop Studio can read."
                : warnings.joined(separator: " ")
        }
        return "Arrows move. Return launches. Escape closes. Discovery reads Applications folders only."
    }

    private func rowView(_ row: LauncherListRow) -> some View {
        HStack(spacing: model.component.settings.launcherSpacing) {
            icon(for: row)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: appearance.fontSize, weight: .medium, design: appearance.fontDesign.fontDesign))
                if let group = row.groupName {
                    Text(group)
                        .font(.caption)
                        .foregroundStyle(appearance.foreground.color.opacity(0.65))
                }
            }
            Spacer()
            if row.missing {
                Text("Missing")
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel("\(row.title), unavailable")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.missing ? "\(row.title), unavailable" : "Launch \(row.title)")
        .accessibilityAddTraits(selection == row.index ? .isSelected : [])
        .onTapGesture { activate(row) }
    }

    @ViewBuilder
    private func icon(for row: LauncherListRow) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: row.bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .opacity(row.missing ? 0.4 : 1)
        } else {
            Image(systemName: "app")
                .foregroundStyle(appearance.accent.color.opacity(row.missing ? 0.45 : 1))
        }
    }

    private func reloadCatalog() {
        let result = LauncherCatalog.scan(roots: LauncherCatalog.standardRoots())
        applications = result.applications
        warnings = result.warnings
    }

    private func move(_ delta: Int) {
        guard !rows.isEmpty else { return }
        selection = min(max(selection + delta, 0), rows.count - 1)
    }

    private func activateSelection() {
        guard rows.indices.contains(selection) else { return }
        activate(rows[selection])
    }

    private func activate(_ row: LauncherListRow) {
        guard !row.missing else { return }
        onLaunch(row.bundleIdentifier)
        onDismiss()
    }
}

struct LauncherListRow: Identifiable, Equatable {
    var index: Int
    var title: String
    var bundleIdentifier: String
    var groupName: String?
    var missing: Bool

    var id: String { "\(index)-\(bundleIdentifier)-\(title)" }
}

enum LauncherList {
    static func rows(
        favorites: [LauncherFavorite],
        applications: [InstalledApplication],
        query: String
    ) -> [LauncherListRow] {
        let installed = Set(applications.map(\.bundleIdentifier))
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var rows: [LauncherListRow] = []
        for group in LauncherSearch.grouped(favorites) {
            for favorite in group.items {
                let matches = trimmed.isEmpty
                    || favorite.title.localizedCaseInsensitiveContains(trimmed)
                    || favorite.bundleIdentifier.localizedCaseInsensitiveContains(trimmed)
                guard matches else { continue }
                let identifier = favorite.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                rows.append(LauncherListRow(
                    index: rows.count,
                    title: favorite.title,
                    bundleIdentifier: identifier,
                    groupName: group.name,
                    missing: identifier.isEmpty || !installed.contains(identifier)
                ))
            }
        }
        if !trimmed.isEmpty {
            for app in LauncherSearch.filter(applications, query: trimmed) {
                rows.append(LauncherListRow(
                    index: rows.count,
                    title: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    groupName: nil,
                    missing: false
                ))
            }
        }
        return rows
    }
}
