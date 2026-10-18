import Foundation

struct DesktopComponent: Codable, Hashable, Identifiable {
    var id: UUID
    var type: ComponentType
    var name: String
    var frame: ComponentFrame
    var appearance: ComponentAppearance
    var settings: ComponentSettings
}
