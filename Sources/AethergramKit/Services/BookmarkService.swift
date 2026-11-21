import Foundation

public enum BookmarkCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case message = "Messages"
    case photo = "Photos"
    case video = "Videos"
    case file = "Files & Voice"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .message: return "text.bubble.fill"
        case .photo: return "photo.fill"
        case .video: return "play.rectangle.fill"
        case .file: return "doc.fill"
        }
    }
}

public struct BookmarkItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let messageId: String
    public let chatId: String
    public let chatTitle: String
    public let topicId: Int64?
    public let topicName: String?
    public let senderName: String
    public let text: String
    public let timestamp: String
    public let dateGroup: String
    public let bookmarkedAt: Date
    public let category: BookmarkCategory
    public var albumTag: String

    // Stored media metadata for photo, video, voice, and document bookmarks
    public let mediaKindRaw: String?
    public let mediaFileId: Int32?
    public var mediaLocalPath: String?
    public let thumbnailFileId: Int32?
    public var thumbnailLocalPath: String?
    public let minithumbnailBase64: String?
    public let mediaWidth: Int
    public let mediaHeight: Int
    public let mediaDuration: Int
    public let mediaFileName: String?
    public let mediaFileSize: Int64

    public init(
        message: Message,
        chatTitle: String,
        topicId: Int64? = nil,
        topicName: String? = nil,
        albumTag: String = "Saved",
        bookmarkedAt: Date = Date()
    ) {
        self.id = "\(message.chatId)_\(message.id)"
        self.messageId = message.id
        self.chatId = message.chatId
        self.chatTitle = chatTitle
        self.topicId = topicId
        self.topicName = topicName
        self.senderName = message.senderName
        self.text = message.text
        self.timestamp = message.timestamp
        self.dateGroup = message.dateGroup
        self.bookmarkedAt = bookmarkedAt
        self.albumTag = albumTag

        if let media = message.media {
            self.mediaKindRaw = media.kind.rawValue
            self.mediaFileId = media.fileId
            self.mediaLocalPath = media.localPath
            self.thumbnailFileId = media.thumbnailFileId
            self.thumbnailLocalPath = media.thumbnailLocalPath
            self.minithumbnailBase64 = media.minithumbnailBase64
            self.mediaWidth = media.width
            self.mediaHeight = media.height
            self.mediaDuration = media.duration
            self.mediaFileName = media.fileName
            self.mediaFileSize = media.fileSize

            switch media.kind {
            case .photo, .sticker:
                self.category = .photo
            case .video, .animation, .videoNote:
                self.category = .video
            case .voiceNote, .document:
                self.category = .file
            }
        } else {
            self.mediaKindRaw = nil
            self.mediaFileId = nil
            self.mediaLocalPath = nil
            self.thumbnailFileId = nil
            self.thumbnailLocalPath = nil
            self.minithumbnailBase64 = nil
            self.mediaWidth = 0
            self.mediaHeight = 0
            self.mediaDuration = 0
            self.mediaFileName = nil
            self.mediaFileSize = 0
            self.category = .message
        }
    }

    public var reconstructedMedia: MessageMedia? {
        guard let raw = mediaKindRaw, let kind = MessageMediaKind(rawValue: raw) else {
            return nil
        }
        return MessageMedia(
            kind: kind,
            fileId: mediaFileId,
            localPath: mediaLocalPath,
            thumbnailFileId: thumbnailFileId,
            thumbnailLocalPath: thumbnailLocalPath,
            minithumbnailBase64: minithumbnailBase64,
            width: mediaWidth,
            height: mediaHeight,
            duration: mediaDuration,
            fileName: mediaFileName,
            fileSize: mediaFileSize
        )
    }

    public var reconstructedMessage: Message {
        Message(
            id: messageId,
            chatId: chatId,
            senderName: senderName,
            text: text,
            timestamp: timestamp,
            dateGroup: dateGroup,
            isOutgoing: false,
            media: reconstructedMedia
        )
    }
}

/// iMe-inspired Bookmarks & Cloud Albums persistence service for messages, photos, videos, and files.
public enum BookmarkService {
    public static func defaultStorageURL() -> URL {
        TDLibConfiguration.defaultSupportDirectory()
            .appendingPathComponent("bookmarks.json")
    }

    public static func loadBookmarks(from url: URL = defaultStorageURL()) -> [BookmarkItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([BookmarkItem].self, from: data)) ?? []
    }

    public static func saveBookmarks(_ items: [BookmarkItem], to url: URL = defaultStorageURL()) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        try data.write(to: url, options: .atomic)
    }

    public static func filter(
        _ items: [BookmarkItem],
        category: BookmarkCategory,
        chatId: String? = nil,
        searchQuery: String = ""
    ) -> [BookmarkItem] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if let chatId, item.chatId != chatId {
                return false
            }
            if category != .all && item.category != category {
                return false
            }
            if !trimmedQuery.isEmpty {
                let matchesText = item.text.localizedCaseInsensitiveContains(trimmedQuery)
                let matchesChat = item.chatTitle.localizedCaseInsensitiveContains(trimmedQuery)
                let matchesSender = item.senderName.localizedCaseInsensitiveContains(trimmedQuery)
                let matchesFile = (item.mediaFileName ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                let matchesAlbum = item.albumTag.localizedCaseInsensitiveContains(trimmedQuery)
                let matchesTopic = (item.topicName ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                return matchesText || matchesChat || matchesSender || matchesFile || matchesAlbum || matchesTopic
            }
            return true
        }
    }
}
