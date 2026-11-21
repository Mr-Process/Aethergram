import Foundation

public struct Reaction: Hashable, Sendable {
    public let emoji: String
    public var count: Int
    public var isSelectedByMe: Bool

    public init(emoji: String, count: Int, isSelectedByMe: Bool = false) {
        self.emoji = emoji
        self.count = count
        self.isSelectedByMe = isSelectedByMe
    }
}

public enum MessageDeliveryStatus: String, Sendable {
    case sending
    case sent
    case read
}

public enum MessageMediaKind: String, Hashable, Sendable {
    case photo
    case video
    case animation
    case videoNote
    case sticker
    case voiceNote
    case document
}

public struct MessageMedia: Hashable, Sendable {
    public let kind: MessageMediaKind
    public let fileId: Int32?
    public var localPath: String?
    public let thumbnailFileId: Int32?
    public var thumbnailLocalPath: String?
    public let minithumbnailBase64: String?
    public let width: Int
    public let height: Int
    public let duration: Int
    public let fileName: String?
    public let fileSize: Int64

    public init(
        kind: MessageMediaKind,
        fileId: Int32? = nil,
        localPath: String? = nil,
        thumbnailFileId: Int32? = nil,
        thumbnailLocalPath: String? = nil,
        minithumbnailBase64: String? = nil,
        width: Int = 0,
        height: Int = 0,
        duration: Int = 0,
        fileName: String? = nil,
        fileSize: Int64 = 0
    ) {
        self.kind = kind
        self.fileId = fileId
        self.localPath = localPath
        self.thumbnailFileId = thumbnailFileId
        self.thumbnailLocalPath = thumbnailLocalPath
        self.minithumbnailBase64 = minithumbnailBase64
        self.width = width
        self.height = height
        self.duration = duration
        self.fileName = fileName
        self.fileSize = fileSize
    }

    public var formattedDuration: String {
        let mins = duration / 60
        let secs = duration % 60
        return String(format: "%d:%02d", mins, secs)
    }

    public var formattedFileSize: String {
        guard fileSize > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

public struct Message: Identifiable, Hashable, Sendable {
    public let id: String
    public let chatId: String
    public let senderName: String
    public let text: String
    public let timestamp: String
    public let dateGroup: String
    public let isOutgoing: Bool
    public let isServiceMessage: Bool
    public var status: MessageDeliveryStatus
    public var reactions: [Reaction]
    public let replyToSnippet: String?
    public var media: MessageMedia?
    public let viewsCount: Int?

    public init(
        id: String,
        chatId: String,
        senderName: String,
        text: String,
        timestamp: String,
        dateGroup: String = "Today",
        isOutgoing: Bool,
        isServiceMessage: Bool = false,
        status: MessageDeliveryStatus = .read,
        reactions: [Reaction] = [],
        replyToSnippet: String? = nil,
        media: MessageMedia? = nil,
        viewsCount: Int? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.dateGroup = dateGroup
        self.isOutgoing = isOutgoing
        self.isServiceMessage = isServiceMessage
        self.status = status
        self.reactions = reactions
        self.replyToSnippet = replyToSnippet
        self.media = media
        self.viewsCount = viewsCount
    }
}
