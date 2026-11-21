import Foundation

public enum ChatExportFormat: String, CaseIterable, Identifiable, Sendable {
    case html = "HTML"
    case json = "JSON"
    case both = "HTML + JSON"

    public var id: String { rawValue }
}

public struct ChatExportOptions: Sendable {
    public var format: ChatExportFormat
    public var maxMessages: Int
    public var includePhotos: Bool
    public var includeVideos: Bool
    public var includeVoiceMessages: Bool
    public var includeVideoMessages: Bool
    public var includeStickers: Bool
    public var includeAnimations: Bool
    public var includeDocuments: Bool
    public var destinationDirectory: URL

    public init(
        format: ChatExportFormat = .html,
        maxMessages: Int = 10_000,
        includePhotos: Bool = true,
        includeVideos: Bool = true,
        includeVoiceMessages: Bool = true,
        includeVideoMessages: Bool = true,
        includeStickers: Bool = false,
        includeAnimations: Bool = true,
        includeDocuments: Bool = true,
        destinationDirectory: URL = ChatExportOptions.defaultDestinationDirectory()
    ) {
        self.format = format
        self.maxMessages = max(1, min(10_000, maxMessages))
        self.includePhotos = includePhotos
        self.includeVideos = includeVideos
        self.includeVoiceMessages = includeVoiceMessages
        self.includeVideoMessages = includeVideoMessages
        self.includeStickers = includeStickers
        self.includeAnimations = includeAnimations
        self.includeDocuments = includeDocuments
        self.destinationDirectory = destinationDirectory
    }

    public static func defaultDestinationDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}

public struct ChatExportResult: Sendable {
    public let exportFolderURL: URL
    public let htmlURL: URL?
    public let jsonURL: URL?
    public let messageCount: Int
    public let mediaFilesCopied: Int

    public init(
        exportFolderURL: URL,
        htmlURL: URL?,
        jsonURL: URL?,
        messageCount: Int,
        mediaFilesCopied: Int
    ) {
        self.exportFolderURL = exportFolderURL
        self.htmlURL = htmlURL
        self.jsonURL = jsonURL
        self.messageCount = messageCount
        self.mediaFilesCopied = mediaFilesCopied
    }
}

/// Full Materialgram chat exporter supporting single-document HTML (up to 10,000 messages),
/// structured `result.json`, and selective local media bundling matching Telegram Desktop's layout.
public enum ChatExportService {
    public static let maxMessagesPerDocument = 10_000

    public static func exportChatHTML(
        chat: Chat,
        messages: [Message],
        destinationDirectory: URL? = nil
    ) throws -> URL {
        let dir = destinationDirectory ?? ChatExportOptions.defaultDestinationDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let safeId = chat.id.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let outURL = dir.appendingPathComponent("materialgram_export_\(safeId).html")

        let bounded = Array(messages.prefix(maxMessagesPerDocument))
        let html = buildHTMLDocument(chat: chat, renderedRows: bounded.map { msg in
            (msg, nil)
        }, totalCount: bounded.count)
        try html.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    public static func exportChatBundle(
        chat: Chat,
        messages: [Message],
        options: ChatExportOptions
    ) throws -> ChatExportResult {
        try FileManager.default.createDirectory(at: options.destinationDirectory, withIntermediateDirectories: true)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = dateFmt.string(from: Date())
        let safeName = sanitizedFolderName(chat.title.isEmpty ? chat.id : chat.title)
        let folderURL = options.destinationDirectory.appendingPathComponent("Materialgram_Export_\(safeName)_\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let limit = min(maxMessagesPerDocument, max(1, options.maxMessages))
        let bounded = Array(messages.suffix(limit))

        var copiedCount = 0
        var resolvedRelativePaths: [String: String] = [:]
        var usedPaths = Set<String>()

        for msg in bounded {
            guard let media = msg.media,
                  shouldIncludeMedia(media.kind, options: options),
                  let srcPath = media.localPath,
                  !srcPath.isEmpty,
                  FileManager.default.fileExists(atPath: srcPath) else {
                continue
            }

            let subdir = subfolderName(for: media.kind)
            let targetDir = folderURL.appendingPathComponent(subdir, isDirectory: true)
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

            let srcURL = URL(fileURLWithPath: srcPath)
            let rawName = media.fileName ?? srcURL.lastPathComponent
            let cleanName = sanitizedFilename(rawName.isEmpty ? "media_\(msg.id)" : rawName)
            var candidateRel = "\(subdir)/\(cleanName)"
            if usedPaths.contains(candidateRel) {
                candidateRel = "\(subdir)/\(msg.id)_\(cleanName)"
            }
            usedPaths.insert(candidateRel)

            let dstURL = folderURL.appendingPathComponent(candidateRel)
            try? FileManager.default.removeItem(at: dstURL)
            if (try? FileManager.default.copyItem(at: srcURL, to: dstURL)) != nil {
                resolvedRelativePaths[msg.id] = candidateRel
                copiedCount += 1
            }
        }

        var htmlURL: URL? = nil
        if options.format == .html || options.format == .both {
            let url = folderURL.appendingPathComponent("messages.html")
            let rows = bounded.map { ($0, resolvedRelativePaths[$0.id]) }
            let html = buildHTMLDocument(chat: chat, renderedRows: rows, totalCount: bounded.count)
            try html.write(to: url, atomically: true, encoding: .utf8)
            copyBundledFaviconsIfAvailable(into: folderURL)
            htmlURL = url
        }

        var jsonURL: URL? = nil
        if options.format == .json || options.format == .both {
            let url = folderURL.appendingPathComponent("result.json")
            let jsonData = try buildJSONDocument(chat: chat, messages: bounded, mediaPaths: resolvedRelativePaths)
            try jsonData.write(to: url, options: .atomic)
            jsonURL = url
        }

        return ChatExportResult(
            exportFolderURL: folderURL,
            htmlURL: htmlURL,
            jsonURL: jsonURL,
            messageCount: bounded.count,
            mediaFilesCopied: copiedCount
        )
    }

    private static func copyBundledFaviconsIfAvailable(into folderURL: URL) {
        let bundle = MD3Typography.resourceBundle
        let names = [
            "favicon.ico",
            "favicon.svg",
            "favicon-96x96.png",
            "apple-touch-icon.png",
            "web-app-manifest-192x192.png",
            "web-app-manifest-512x512.png",
            "site.webmanifest"
        ]
        for name in names {
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            if let src = bundle.url(forResource: base, withExtension: ext, subdirectory: "Favicons")
                ?? bundle.url(forResource: base, withExtension: ext) {
                let dst = folderURL.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: dst)
                try? FileManager.default.copyItem(at: src, to: dst)
            }
        }
    }

    private static func shouldIncludeMedia(_ kind: MessageMediaKind, options: ChatExportOptions) -> Bool {
        switch kind {
        case .photo: return options.includePhotos
        case .video: return options.includeVideos
        case .voiceNote: return options.includeVoiceMessages
        case .videoNote: return options.includeVideoMessages
        case .sticker: return options.includeStickers
        case .animation: return options.includeAnimations
        case .document: return options.includeDocuments
        }
    }

    private static func subfolderName(for kind: MessageMediaKind) -> String {
        switch kind {
        case .photo: return "photos"
        case .video, .animation: return "video_files"
        case .voiceNote: return "voice_messages"
        case .videoNote: return "round_video_messages"
        case .sticker: return "stickers"
        case .document: return "files"
        }
    }

    private static func sanitizedFolderName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let replaced = trimmed.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "_", options: .regularExpression)
        let prefix = String(replaced.prefix(40))
        return prefix.isEmpty ? "chat" : prefix
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let base = URL(fileURLWithPath: name).lastPathComponent
        let safe = base.replacingOccurrences(of: "[/:\\\\?%*|\"<>]+", with: "_", options: .regularExpression)
        return safe.isEmpty ? "file.bin" : safe
    }

    private static func buildHTMLDocument(
        chat: Chat,
        renderedRows: [(Message, String?)],
        totalCount: Int
    ) -> String {
        var rows: [String] = []
        rows.reserveCapacity(renderedRows.count)

        for (msg, relPath) in renderedRows {
            if msg.isServiceMessage {
                rows.append("<div class=\"service\">\(escapeHTML(msg.text))</div>")
                continue
            }

            let cls = msg.isOutgoing ? "msg out" : "msg in"
            var mediaHTML = ""
            if let relPath, let media = msg.media {
                let escPath = escapeHTML(relPath)
                switch media.kind {
                case .photo, .sticker:
                    mediaHTML = "<div class=\"media\"><img src=\"\(escPath)\" alt=\"photo\" /></div>"
                case .video, .animation, .videoNote:
                    mediaHTML = "<div class=\"media\"><video controls src=\"\(escPath)\"></video></div>"
                case .voiceNote:
                    mediaHTML = "<div class=\"media\"><audio controls src=\"\(escPath)\"></audio></div>"
                case .document:
                    let label = escapeHTML(media.fileName ?? relPath)
                    mediaHTML = "<div class=\"media\"><a class=\"file-link\" href=\"\(escPath)\">\(label)</a></div>"
                }
            } else if let media = msg.media {
                mediaHTML = "<div class=\"media-note\">[\(escapeHTML(media.kind.rawValue))]</div>"
            }

            var footerParts = ["<span>\(escapeHTML(msg.timestamp))</span>"]
            if let views = msg.viewsCount, views > 0 {
                footerParts.append("<span>\(views) views</span>")
            }
            if !msg.reactions.isEmpty {
                let rxStr = msg.reactions.map { "\($0.emoji) \($0.count)" }.joined(separator: " ")
                footerParts.append("<span>\(escapeHTML(rxStr))</span>")
            }

            let textHTML = msg.text.isEmpty ? "" : "<div class=\"body\">\(escapeHTML(msg.text))</div>"
            rows.append("""
            <div class="\(cls)">
              <div class="meta"><strong>\(escapeHTML(msg.senderName))</strong> · \(escapeHTML(msg.dateGroup))</div>
              \(mediaHTML)
              \(textHTML)
              <div class="foot">\(footerParts.joined(separator: " · "))</div>
            </div>
            """)
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8" />
        <title>\(AethergramBrand.appName) Export - \(escapeHTML(chat.title))</title>
        <link rel="icon" type="image/png" href="favicon-96x96.png" sizes="96x96" />
        <link rel="icon" type="image/svg+xml" href="favicon.svg" />
        <link rel="shortcut icon" href="favicon.ico" />
        <link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png" />
        <meta name="apple-mobile-web-app-title" content="\(AethergramBrand.appName)" />
        <link rel="manifest" href="site.webmanifest" />
        <style>
          body { font-family: "Google Sans", -apple-system, BlinkMacSystemFont, sans-serif; background: #121316; color: #e3e3e8; max-width: 820px; margin: 28px auto; padding: 0 18px; }
          h1 { font-size: 22px; margin-bottom: 4px; color: #ffffff; }
          .sub { color: #9aa0a6; font-size: 13px; margin-bottom: 22px; }
          .service { text-align: center; font-size: 12px; color: #9aa0a6; background: #1e2026; border-radius: 999px; padding: 5px 14px; margin: 10px auto; width: fit-content; }
          .msg { padding: 12px 15px; border-radius: 16px; margin-bottom: 10px; max-width: 78%; border: 1px solid #2a2d36; }
          .msg.in { background: #1e2026; }
          .msg.out { background: #1f334d; margin-left: auto; }
          .meta { font-size: 12px; color: #8ab4f8; margin-bottom: 6px; }
          .body { font-size: 14px; line-height: 1.45; white-space: pre-wrap; }
          .media img, .media video { max-width: 100%; max-height: 380px; border-radius: 10px; margin: 4px 0 8px 0; display: block; }
          .media audio { width: 100%; margin: 4px 0 6px 0; }
          .media-note { font-size: 12px; color: #9aa0a6; font-style: italic; margin-bottom: 4px; }
          .file-link { color: #8ab4f8; text-decoration: none; font-weight: 500; }
          .foot { font-size: 11px; color: #9aa0a6; margin-top: 6px; }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(chat.title))</h1>
        <div class="sub">Exported \(totalCount) messages (max \(maxMessagesPerDocument) per HTML document) via \(AethergramBrand.appName) v\(MaterialgramUpdateService.currentVersion)</div>
        \(rows.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private static func buildJSONDocument(
        chat: Chat,
        messages: [Message],
        mediaPaths: [String: String]
    ) throws -> Data {
        let iso = ISO8601DateFormatter()
        let jsonMessages: [[String: Any]] = messages.map { msg in
            var entry: [String: Any] = [
                "id": Int64(msg.id) ?? 0,
                "type": msg.isServiceMessage ? "service" : "message",
                "date": "\(msg.dateGroup) \(msg.timestamp)",
                "from": msg.senderName,
                "text": msg.text
            ]
            if let media = msg.media {
                entry["media_type"] = jsonMediaType(media.kind)
                if media.duration > 0 {
                    entry["duration_seconds"] = media.duration
                }
            }
            if let rel = mediaPaths[msg.id] {
                entry["file"] = rel
            }
            if let views = msg.viewsCount {
                entry["views"] = views
            }
            return entry
        }

        let root: [String: Any] = [
            "name": chat.title,
            "type": chat.type.rawValue,
            "id": Int64(chat.id) ?? 0,
            "exported_at": iso.string(from: Date()),
            "messages": jsonMessages
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static func jsonMediaType(_ kind: MessageMediaKind) -> String {
        switch kind {
        case .photo: return "photo"
        case .video: return "video_file"
        case .animation: return "animation"
        case .videoNote: return "video_message"
        case .sticker: return "sticker"
        case .voiceNote: return "voice_message"
        case .document: return "document"
        }
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
