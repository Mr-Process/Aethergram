import Foundation

public struct Folder: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String
    public let badgeCount: Int

    public init(id: String, name: String, iconName: String, badgeCount: Int = 0) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.badgeCount = badgeCount
    }
}
