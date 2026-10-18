import SwiftUI

struct ComponentCardView: View {
    var component: DesktopComponent
    var appearance: ComponentAppearance
    var spacing: Double
    var scale: CGFloat

    var body: some View {
        let appearance = appearance.sanitized()
        let radius = appearance.cornerRadius * scale
        content(appearance)
            .padding(padding(for: component.type) * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: component.type))
            .background(appearance.background.color)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        appearance.borderColor.color,
                        lineWidth: appearance.borderWidth * scale
                    )
            }
            .shadow(
                color: .black.opacity(appearance.shadowEnabled ? 0.28 : 0),
                radius: appearance.shadowEnabled ? 18 * scale : 0,
                y: appearance.shadowEnabled ? 8 * scale : 0
            )
            .opacity(appearance.opacity)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func content(_ appearance: ComponentAppearance) -> some View {
        switch component.type {
        case .clock:
            ClockFace(component: component, appearance: appearance, scale: scale)
        case .text:
            TextBlock(component: component, appearance: appearance, scale: scale, showsBody: true)
        case .notes:
            TextBlock(component: component, appearance: appearance, scale: scale, showsBody: true)
        case .appShortcut:
            ShortcutFace(component: component, appearance: appearance, scale: scale)
        case .dock:
            DockFace(component: component, appearance: appearance, scale: scale)
        }
    }

    private func padding(for type: ComponentType) -> CGFloat {
        let base = min(max(spacing, 0), ThemeLimits.maxSpacing)
        switch type {
        case .dock: max(6, base * 0.55)
        case .appShortcut: max(8, base * 0.7)
        default: max(10, base)
        }
    }

    private func alignment(for type: ComponentType) -> Alignment {
        switch type {
        case .dock: .center
        case .appShortcut: .leading
        default: .topLeading
        }
    }
}

private struct ClockFace: View {
    var component: DesktopComponent
    var appearance: ComponentAppearance
    var scale: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4 * scale) {
                if component.settings.showsDate {
                    Text(Self.dateText(context.date))
                        .font(font(size: max(11, appearance.fontSize * 0.28), weight: .medium))
                        .foregroundStyle(appearance.accent.color)
                        .lineLimit(1)
                }
                Text(Self.timeText(context.date, settings: component.settings))
                    .font(font(size: appearance.fontSize, weight: appearance.fontWeight.fontWeight))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(appearance.foreground.color)
                if !component.settings.title.isEmpty {
                    Text(component.settings.title)
                        .font(font(size: max(10, appearance.fontSize * 0.24), weight: .regular))
                        .foregroundStyle(appearance.foreground.color.opacity(0.68))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(at: context.date))
        }
    }

    private func accessibilityLabel(at date: Date) -> String {
        var parts = [component.name, Self.timeText(date, settings: component.settings)]
        if component.settings.showsDate {
            parts.append(Self.dateText(date))
        }
        return parts.joined(separator: ", ")
    }

    private func font(size: CGFloat, weight: Font.Weight) -> Font {
        Font.system(size: max(8, size * scale), weight: weight, design: appearance.fontDesign.fontDesign)
    }

    private static func timeText(_ date: Date, settings: ComponentSettings) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        switch settings.timeFormat {
        case .system:
            formatter.timeStyle = settings.showsSeconds ? .medium : .short
            formatter.dateStyle = .none
        case .twelveHour:
            formatter.dateFormat = settings.showsSeconds ? "h:mm:ss a" : "h:mm a"
        case .twentyFourHour:
            formatter.dateFormat = settings.showsSeconds ? "HH:mm:ss" : "HH:mm"
        }
        return formatter.string(from: date)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter.string(from: date)
    }
}

private struct TextBlock: View {
    var component: DesktopComponent
    var appearance: ComponentAppearance
    var scale: CGFloat
    var showsBody: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text(component.settings.title.isEmpty ? component.name : component.settings.title)
                .font(font(size: appearance.fontSize, weight: appearance.fontWeight.fontWeight))
                .foregroundStyle(appearance.foreground.color)
                .lineLimit(component.type == .notes ? 2 : 3)
            if showsBody, !component.settings.body.isEmpty {
                Text(component.settings.body)
                    .font(font(size: max(12, appearance.fontSize * 0.42), weight: .regular))
                    .foregroundStyle(appearance.foreground.color.opacity(0.78))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func font(size: CGFloat, weight: Font.Weight) -> Font {
        Font.system(size: max(8, size * scale), weight: weight, design: appearance.fontDesign.fontDesign)
    }
}

private struct ShortcutFace: View {
    var component: DesktopComponent
    var appearance: ComponentAppearance
    var scale: CGFloat

    var body: some View {
        HStack(spacing: 12 * scale) {
            ZStack {
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .fill(appearance.accent.color.opacity(0.18))
                Image(systemName: symbol)
                    .font(.system(size: max(12, appearance.fontSize * scale), weight: .semibold))
                    .foregroundStyle(appearance.accent.color)
                    .accessibilityHidden(true)
            }
            .frame(width: 44 * scale, height: 44 * scale)
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(component.settings.title.isEmpty ? component.name : component.settings.title)
                    .font(.system(size: max(11, appearance.fontSize * scale), weight: .semibold, design: appearance.fontDesign.fontDesign))
                    .foregroundStyle(appearance.foreground.color)
                    .lineLimit(1)
                Text("Shortcut")
                    .font(.system(size: max(9, appearance.fontSize * 0.72 * scale), weight: .regular))
                    .foregroundStyle(appearance.foreground.color.opacity(0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var symbol: String {
        let trimmed = component.settings.symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "app.fill" : trimmed
    }
}

private struct DockFace: View {
    var component: DesktopComponent
    var appearance: ComponentAppearance
    var scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            if component.settings.dockItems.isEmpty {
                Text("No apps yet")
                    .font(.system(size: max(10, 13 * scale), weight: .medium))
                    .foregroundStyle(appearance.foreground.color.opacity(0.7))
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(component.settings.dockItems) { item in
                    VStack(spacing: 4 * scale) {
                        Image(systemName: symbol(item.symbolName))
                            .font(.system(size: max(12, appearance.fontSize * scale), weight: .regular))
                            .foregroundStyle(appearance.foreground.color)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.system(size: max(8, 10 * scale)))
                            .foregroundStyle(appearance.foreground.color.opacity(0.78))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.title)
                }
            }
        }
    }

    private func symbol(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "app.fill" : trimmed
    }
}
