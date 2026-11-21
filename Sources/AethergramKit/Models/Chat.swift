import Foundation

public enum ChatType: String, Codable, Sendable {
    case direct
    case group
    case channel
    case bot
}

public struct ForumTopic: Identifiable, Hashable, Sendable {
    public let id: Int64
    public let chatId: String
    public let name: String
    public let iconColorHex: Int
    public let isGeneral: Bool
    public let isPinned: Bool
    public let isClosed: Bool
    public let unreadCount: Int
    public let lastMessagePreview: String
    public let lastMessageTime: String
    public let isDirectMessageTopic: Bool

    public init(
        id: Int64,
        chatId: String,
        name: String,
        iconColorHex: Int = 0x6FB9F0,
        isGeneral: Bool = false,
        isPinned: Bool = false,
        isClosed: Bool = false,
        unreadCount: Int = 0,
        lastMessagePreview: String = "",
        lastMessageTime: String = "",
        isDirectMessageTopic: Bool = false
    ) {
        self.id = id
        self.chatId = chatId
        self.name = name
        self.iconColorHex = iconColorHex
        self.isGeneral = isGeneral
        self.isPinned = isPinned
        self.isClosed = isClosed
        self.unreadCount = unreadCount
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageTime = lastMessageTime
        self.isDirectMessageTopic = isDirectMessageTopic
    }
}

public struct Chat: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let avatarInitials: String
    public let avatarHue: Double
    public var avatarFileId: Int32?
    public var avatarLocalPath: String?
    public let lastMessagePreview: String
    public let lastMessageTime: String
    public let unreadCount: Int
    public let isPinned: Bool
    public let isMuted: Bool
    public let isOnline: Bool
    public let type: ChatType
    public let isForum: Bool
    public let isDirectMessagesGroup: Bool
    public let memberCount: Int?
    public let username: String?
    public let datacenterId: Int?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        avatarInitials: String,
        avatarHue: Double = 0.5,
        avatarFileId: Int32? = nil,
        avatarLocalPath: String? = nil,
        lastMessagePreview: String,
        lastMessageTime: String,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isOnline: Bool = false,
        type: ChatType = .direct,
        isForum: Bool = false,
        isDirectMessagesGroup: Bool = false,
        memberCount: Int? = nil,
        username: String? = nil,
        datacenterId: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.avatarInitials = avatarInitials
        self.avatarHue = avatarHue
        self.avatarFileId = avatarFileId
        self.avatarLocalPath = avatarLocalPath
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isOnline = isOnline
        self.type = type
        self.isForum = isForum
        self.isDirectMessagesGroup = isDirectMessagesGroup
        self.memberCount = memberCount
        self.username = username
        self.datacenterId = datacenterId
    }
}
