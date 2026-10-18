import Foundation

struct DesktopComponent: Codable, Hashable, Identifiable {
    var id: UUID
    var type: ComponentType
    var name: String
    var frame: ComponentFrame
    var overrides: AppearanceOverrides
    var settings: ComponentSettings

    func resolvedAppearance(in theme: Theme) -> ComponentAppearance {
        StyleResolver.resolve(self, theme: theme)
    }
}
