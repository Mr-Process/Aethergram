import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Reusable Material You 3 avatar that renders a real downloaded Telegram photo
/// when available and falls back to clean alphanumeric initials.
public struct MD3AvatarView: View {
    public let localPath: String?
    public let initials: String
    public let hue: Double
    public let size: CGFloat

    public init(localPath: String?, initials: String, hue: Double, size: CGFloat) {
        self.localPath = localPath
        self.initials = initials
        self.hue = hue
        self.size = size
    }

    public var body: some View {
        #if os(macOS)
        if let localPath, !localPath.isEmpty, let img = NSImage(contentsOfFile: localPath) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        } else {
            fallbackCircle
        }
        #else
        fallbackCircle
        #endif
    }

    private var fallbackCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.62, brightness: 0.78),
                        Color(hue: (hue + 0.06).truncatingRemainder(dividingBy: 1.0), saturation: 0.70, brightness: 0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: max(11, size * 0.36), weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            )
    }
}

public struct MessageBubbleView: View {
    public let message: Message
    public let palette: MD3ColorPalette
    public let baseRadius: CGFloat
    public let isDownloadingMedia: Bool
    public let isPlayingVoice: Bool
    public let isBookmarked: Bool
    public let isPinned: Bool
    public let onReply: (Message) -> Void
    public let onReact: (String, String) -> Void
    public let onOpenMedia: (Message) -> Void
    public let onToggleVoice: (Message) -> Void
    public let onToggleBookmark: (Message, Bool) -> Void
    public let onTogglePin: (Message) -> Void

    private var bubbleBg: Color {
        message.isOutgoing ? palette.bubbleOutgoing : palette.bubbleIncoming
    }

    private var textColor: Color {
        message.isOutgoing ? palette.onBubbleOutgoing : palette.onBubbleIncoming
    }

    private var timeColor: Color {
        textColor.opacity(0.62)
    }

    public init(
        message: Message,
        palette: MD3ColorPalette,
        baseRadius: CGFloat = 16,
        isDownloadingMedia: Bool = false,
        isPlayingVoice: Bool = false,
        isBookmarked: Bool = false,
        isPinned: Bool = false,
        onReply: @escaping (Message) -> Void,
        onReact: @escaping (String, String) -> Void,
        onOpenMedia: @escaping (Message) -> Void = { _ in },
        onToggleVoice: @escaping (Message) -> Void = { _ in },
        onToggleBookmark: @escaping (Message, Bool) -> Void = { _, _ in },
        onTogglePin: @escaping (Message) -> Void = { _ in }
    ) {
        self.message = message
        self.palette = palette
        self.baseRadius = baseRadius
        self.isDownloadingMedia = isDownloadingMedia
        self.isPlayingVoice = isPlayingVoice
        self.isBookmarked = isBookmarked
        self.isPinned = isPinned
        self.onReply = onReply
        self.onReact = onReact
        self.onOpenMedia = onOpenMedia
        self.onToggleVoice = onToggleVoice
        self.onToggleBookmark = onToggleBookmark
        self.onTogglePin = onTogglePin
    }

    public var body: some View {
        if message.isServiceMessage {
            HStack {
                Spacer()
                Text(message.text)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .mgGlassCapsule(tint: palette.surfaceContainerHigh.opacity(0.45))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isOutgoing {
                    Spacer(minLength: 64)
                }

                VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !message.isOutgoing && !message.senderName.isEmpty {
                            Text(message.senderName)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(palette.primary)
                                .lineLimit(1)
                        }

                        if let reply = message.replyToSnippet {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(palette.primary)
                                    .frame(width: 3, height: 22)
                                Text(reply)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(palette.surfaceContainerHigh.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if let media = message.media {
                            mediaBlock(media)
                        }

                        if !message.text.isEmpty {
                            Text(message.text)
                                .font(.system(size: 14))
                                .foregroundColor(textColor)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }

                        // Compact Metadata Footer (Pin + Bookmark + Views + Time + Delivery)
                        HStack(spacing: 6) {
                            Button {
                                onTogglePin(message)
                            } label: {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 10, weight: isPinned ? .bold : .regular))
                                    .foregroundColor(isPinned ? palette.primary : timeColor)
                            }
                            .buttonStyle(.plain)
                            .help(isPinned ? "Unpin Message" : "Pin Message in Chat")

                            Button {
                                onToggleBookmark(message, false)
                            } label: {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 10.5, weight: isBookmarked ? .bold : .regular))
                                    .foregroundColor(isBookmarked ? palette.primary : timeColor)
                            }
                            .buttonStyle(.plain)
                            .help(isBookmarked ? "Remove Bookmark" : "Bookmark message, photo, or video")

                            if let views = message.viewsCount, views > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 9.5))
                                    Text(formatCompactCount(views))
                                        .font(.system(size: 10.5, design: .rounded))
                                }
                                .foregroundColor(timeColor)
                            }

                            Text(message.timestamp)
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundColor(timeColor)

                            if message.isOutgoing {
                                deliveryIcon
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minWidth: 92, maxWidth: 460, alignment: .leading)
                    .fixedSize(horizontal: message.media == nil && message.text.count < 42, vertical: true)
                    .background(bubbleBg)
                    .clipShape(
                        MD3BubbleShape(isOutgoing: message.isOutgoing, baseRadius: baseRadius, tailRadius: 4)
                    )
                    .overlay(
                        MD3BubbleShape(isOutgoing: message.isOutgoing, baseRadius: baseRadius, tailRadius: 4)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.16),
                                        palette.outlineVariant.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.65
                            )
                    )

                    if !message.reactions.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(message.reactions.prefix(6), id: \.emoji) { r in
                                MD3ReactionChip(
                                    emoji: r.emoji,
                                    count: r.count,
                                    isSelected: r.isSelectedByMe,
                                    primaryColor: palette.primary
                                ) {
                                    onReact(message.id, r.emoji)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .contextMenu {
                    if !message.text.isEmpty {
                        Button(action: copyMessageText) {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                    }

                    if message.media != nil {
                        Button {
                            onOpenMedia(message)
                        } label: {
                            Label("Open Media", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    }

                    Button {
                        onTogglePin(message)
                    } label: {
                        Label(
                            isPinned ? "Unpin Message" : "Pin Message in Chat",
                            systemImage: isPinned ? "pin.slash.fill" : "pin.fill"
                        )
                    }

                    Button {
                        onToggleBookmark(message, false)
                    } label: {
                        Label(
                            isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                            systemImage: isBookmarked ? "bookmark.slash.fill" : "bookmark.fill"
                        )
                    }

                    Button {
                        onToggleBookmark(message, true)
                    } label: {
                        Label("Bookmark & Save to Telegram Cloud", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        onReply(message)
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }

                    Menu("React") {
                        Button("👍 Thumbs Up") { onReact(message.id, "👍") }
                        Button("❤️ Heart") { onReact(message.id, "❤️") }
                        Button("🔥 Fire") { onReact(message.id, "🔥") }
                        Button("🎉 Party") { onReact(message.id, "🎉") }
                        Button("👏 Clap") { onReact(message.id, "👏") }
                    }
                }

                if !message.isOutgoing {
                    Spacer(minLength: 64)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private func mediaBlock(_ media: MessageMedia) -> some View {
        switch media.kind {
        case .photo, .sticker:
            let maxW: CGFloat = media.kind == .sticker ? 160 : 360
            let maxH: CGFloat = media.kind == .sticker ? 160 : 320
            Button {
                onOpenMedia(message)
            } label: {
                ZStack {
                    if let img = loadPreviewImage(path: media.localPath ?? media.thumbnailLocalPath, minithumb: media.minithumbnailBase64) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: maxW, maxHeight: maxH)
                            .blur(radius: media.localPath == nil && media.thumbnailLocalPath == nil ? 6 : 0)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surfaceContainerHigh)
                            .frame(width: min(maxW, 240), height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 26))
                                    .foregroundColor(.secondary)
                            )
                    }

                    if (media.localPath == nil && media.kind == .photo) || isDownloadingMedia {
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                            .mgGlassCircle()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)

        case .video, .animation, .videoNote:
            let isRound = (media.kind == .videoNote)
            let targetW: CGFloat = isRound ? 210 : 340
            let targetH: CGFloat = isRound ? 210 : 220
            Button {
                onOpenMedia(message)
            } label: {
                ZStack {
                    if let img = loadPreviewImage(path: media.thumbnailLocalPath, minithumb: media.minithumbnailBase64) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: targetW, height: targetH)
                            .blur(radius: media.thumbnailLocalPath == nil ? 5 : 0)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(palette.surfaceContainerHigh)
                            .frame(width: targetW, height: targetH)
                    }

                    Color.black.opacity(0.20)

                    if isDownloadingMedia {
                        VStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading video...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .mgGlassCapsule(tint: Color.black.opacity(0.45))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .offset(x: 1.5)
                            .frame(width: 50, height: 50)
                            .mgGlassCircle(
                                tint: Color.black.opacity(0.38),
                                interactive: true
                            )
                    }

                    // Top-left Liquid Glass duration & size badge
                    VStack {
                        HStack(spacing: 6) {
                            let badgeText = media.kind == .animation ? "GIF" : media.formattedDuration
                            let sizeSuffix = media.formattedFileSize.isEmpty ? "" : " · \(media.formattedFileSize)"
                            Text("\(badgeText)\(sizeSuffix)")
                                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .mgGlassCapsule(tint: Color.black.opacity(0.42))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(width: targetW, height: targetH)
                .clipShape(RoundedRectangle(cornerRadius: isRound ? targetW / 2 : 12, style: .continuous))
            }
            .buttonStyle(.plain)

        case .voiceNote:
            Button {
                onToggleVoice(message)
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(palette.primary)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if isDownloadingMedia {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: isPlayingVoice ? "stop.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(palette.onPrimary)
                                    .offset(x: isPlayingVoice ? 0 : 1)
                            }
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isPlayingVoice ? "Playing voice message" : "Voice message")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(textColor)
                        Text(media.formattedDuration)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(timeColor)
                    }
                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .mgGlassCard(cornerRadius: 11, tint: palette.surfaceContainerHigh.opacity(0.35), interactive: true)
            }
            .buttonStyle(.plain)

        case .document:
            Button {
                onOpenMedia(message)
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.primary.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "doc.fill")
                                .font(.system(size: 16))
                                .foregroundColor(palette.primary)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.fileName ?? "Document")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if !media.formattedFileSize.isEmpty {
                            Text(media.formattedFileSize)
                                .font(.system(size: 11))
                                .foregroundColor(timeColor)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .mgGlassCard(cornerRadius: 11, tint: palette.surfaceContainerHigh.opacity(0.35), interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var deliveryIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 9))
                .foregroundColor(textColor.opacity(0.6))
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(textColor.opacity(0.7))
        case .read:
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(palette.primary)
        }
    }

    private func copyMessageText() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
        #endif
    }

    #if os(macOS)
    private func loadPreviewImage(path: String?, minithumb: String?) -> NSImage? {
        if let path, !path.isEmpty, let img = NSImage(contentsOfFile: path) {
            return img
        }
        if let minithumb, !minithumb.isEmpty,
           let data = Data(base64Encoded: minithumb),
           let img = NSImage(data: data) {
            return img
        }
        return nil
    }
    #endif

    private func formatCompactCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000.0)
        }
        return "\(n)"
    }
}
