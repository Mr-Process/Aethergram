import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct ConversationView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette

    public init(store: ChatStore, palette: MD3ColorPalette) {
        self.store = store
        self.palette = palette
    }

    public var body: some View {
        if let chat = store.selectedChat {
            HStack(spacing: 0) {
                ZStack {
                    ConversationWallpaper(
                        preset: store.wallpaperPreset,
                        customPhotoPath: store.customWallpaperPath,
                        blurRadius: store.wallpaperBlurRadius,
                        dimming: store.wallpaperDimming,
                        showPattern: store.showWallpaperPattern,
                        palette: palette
                    )

                    VStack(spacing: 0) {
                        ConversationHeaderBar(
                            chat: chat,
                            isProxyEnabled: store.isProxyEnabled,
                            isRecordingVoice: store.voiceRecorder.isRecording,
                            showInChatSearch: store.showInChatSearch,
                            showInspector: store.showInspector,
                            bookmarkCount: store.bookmarks.count,
                            palette: palette,
                            onStartCall: startCall,
                            onToggleVoiceRecording: toggleVoiceRecording,
                            onOpenBookmarks: { store.showBookmarksSheet = true },
                            onToggleSearch: toggleSearch,
                            onToggleInspector: toggleInspector
                        )

                        CallSignalingBannerView(store: store, palette: palette)

                        if chat.isForum || chat.isDirectMessagesGroup || !store.activeChatTopics.isEmpty {
                            TopicsBarView(
                                topics: store.activeChatTopics,
                                selectedTopicId: store.selectedTopicId,
                                isLoadingTopics: store.isLoadingTopics,
                                palette: palette,
                                onSelectTopic: selectTopic
                            )
                        }

                        if store.showInChatSearch {
                            InChatSearchBar(query: $store.inChatSearchQuery, palette: palette)
                        }

                        MessageFeedView(
                            messages: store.filteredMessages,
                            selectedChatId: store.selectedChatId,
                            scrollToMessageIdRequest: store.scrollToMessageIdRequest,
                            isLoadingMessages: store.isLoadingMessages,
                            canLoadOlderMessages: store.canLoadOlderMessages,
                            isLoadingOlderMessages: store.isLoadingOlderMessages,
                            downloadingMediaMessageId: store.downloadingMediaMessageId,
                            playingVoiceMessageId: store.playingVoiceMessageId,
                            bookmarkedIds: Set(store.bookmarks.map(\.messageId)),
                            bubbleCornerRadius: store.bubbleCornerRadius,
                            palette: palette,
                            onLoadOlder: loadOlderMessages,
                            onReply: { store.replyingToMessage = $0 },
                            onReact: toggleReaction,
                            onOpenMedia: openMediaViewer,
                            onToggleVoice: toggleVoicePlayback,
                            onToggleBookmark: { msg, syncCloud in
                                store.toggleBookmark(for: msg, syncToTelegramCloud: syncCloud)
                            }
                        )

                        MessageInputBar(
                            text: $store.inputText,
                            replyingTo: store.replyingToMessage,
                            palette: palette,
                            onDismissReply: { store.replyingToMessage = nil },
                            onAttach: chooseAttachment,
                            onSend: sendMessage
                        )
                    }
                }

                if store.showInspector {
                    ChatInspectorView(store: store, chat: chat, palette: palette) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.showInspector = false
                        }
                    }
                    .transition(.move(edge: .trailing))
                }
            }
            .background(palette.surface)
        } else {
            EmptyConversationPlaceholder(
                isReady: store.tdlibAuthState == .ready,
                palette: palette,
                onSignIn: {
                    store.selectedSettingsSection = .myAccount
                    store.showSettingsSheet = true
                }
            )
        }
    }

    private func startCall() {
        Task { await store.startCallForSelectedChat() }
    }

    private func toggleVoiceRecording() {
        Task { await store.toggleVoiceRecording() }
    }

    private func toggleSearch() {
        withAnimation(.easeInOut(duration: 0.15)) {
            store.showInChatSearch.toggle()
            if !store.showInChatSearch {
                store.inChatSearchQuery = ""
            }
        }
    }

    private func toggleInspector() {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.showInspector.toggle()
        }
    }

    private func selectTopic(_ topic: ForumTopic?) {
        Task { await store.selectTopic(topic) }
    }

    private func loadOlderMessages() {
        Task { await store.loadOlderMessages() }
    }

    private func toggleReaction(messageId: String, emoji: String) {
        Task { await store.toggleReaction(messageId: messageId, emoji: emoji) }
    }

    private func openMediaViewer(_ message: Message) {
        Task { await store.openMediaViewer(for: message) }
    }

    private func toggleVoicePlayback(_ message: Message) {
        Task { await store.toggleVoiceNotePlayback(for: message) }
    }

    private func sendMessage() {
        Task { await store.sendCurrentMessage() }
    }

    private func chooseAttachment() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.lowercased()
            let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp"]
            if imageExtensions.contains(ext) {
                store.activePhotoEditURL = url
            } else {
                Task { await store.sendAttachment(fileURL: url) }
            }
        }
        #endif
    }
}

// MARK: - Extracted Conversation Subviews

private struct ConversationHeaderBar: View {
    let chat: Chat
    let isProxyEnabled: Bool
    let isRecordingVoice: Bool
    let showInChatSearch: Bool
    let showInspector: Bool
    let bookmarkCount: Int
    let palette: MD3ColorPalette
    let onStartCall: () -> Void
    let onToggleVoiceRecording: () -> Void
    let onOpenBookmarks: () -> Void
    let onToggleSearch: () -> Void
    let onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MD3AvatarView(
                localPath: chat.avatarLocalPath,
                initials: chat.avatarInitials,
                hue: chat.avatarHue,
                size: 38
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(chat.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(palette.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isProxyEnabled {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Proxy")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .foregroundColor(.green)
                        .mgGlassCapsule(tint: Color.green.opacity(0.16))
                    }
                }

                if let sub = chat.subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(chat.isOnline ? palette.primary : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            LiquidGlassContainer(spacing: 6) {
                HStack(spacing: 6) {
                    HeaderGlassButton(
                        systemName: "phone",
                        tint: .secondary,
                        isActive: false,
                        palette: palette,
                        help: "Start TDLib call signaling",
                        action: onStartCall
                    )

                    HeaderGlassButton(
                        systemName: isRecordingVoice ? "stop.circle.fill" : "mic",
                        tint: isRecordingVoice ? .red : .secondary,
                        isActive: isRecordingVoice,
                        palette: palette,
                        help: isRecordingVoice ? "Stop and send voice note (256 kbps)" : "Record voice note (256 kbps)",
                        action: onToggleVoiceRecording
                    )

                    HeaderGlassButton(
                        systemName: bookmarkCount > 0 ? "bookmark.fill" : "bookmark",
                        tint: bookmarkCount > 0 ? palette.primary : .secondary,
                        isActive: bookmarkCount > 0,
                        palette: palette,
                        help: "Bookmarks & Cloud Albums (\(bookmarkCount))",
                        action: onOpenBookmarks
                    )

                    HeaderGlassButton(
                        systemName: "magnifyingglass",
                        tint: showInChatSearch ? palette.primary : .secondary,
                        isActive: showInChatSearch,
                        palette: palette,
                        help: "Search in chat",
                        action: onToggleSearch
                    )

                    HeaderGlassButton(
                        systemName: "sidebar.right",
                        tint: showInspector ? palette.primary : .secondary,
                        isActive: showInspector,
                        palette: palette,
                        help: "Toggle chat info",
                        action: onToggleInspector
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(palette.surfaceContainerLow.opacity(0.88))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(palette.outlineVariant.opacity(0.24)),
            alignment: .bottom
        )
    }
}

private struct HeaderGlassButton: View {
    let systemName: String
    let tint: Color
    let isActive: Bool
    let palette: MD3ColorPalette
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .mgGlassCircle(
                    tint: isActive ? palette.primary.opacity(0.2) : palette.surfaceContainer.opacity(0.35),
                    interactive: true
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct TopicsBarView: View {
    let topics: [ForumTopic]
    let selectedTopicId: Int64?
    let isLoadingTopics: Bool
    let palette: MD3ColorPalette
    let onSelectTopic: (ForumTopic?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LiquidGlassContainer(spacing: 6) {
                HStack(spacing: 6) {
                    if isLoadingTopics && topics.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Loading topics...")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    } else {
                        let isAllSelected = (selectedTopicId == nil)
                        Button {
                            onSelectTopic(nil)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "tray.full.fill")
                                    .font(.system(size: 11))
                                Text("All Messages")
                                    .font(.system(size: 12, weight: isAllSelected ? .semibold : .medium))
                            }
                            .foregroundColor(isAllSelected ? palette.onPrimary : palette.onSurface)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .mgGlassCapsule(
                                tint: isAllSelected ? palette.primary : palette.surfaceContainer.opacity(0.45),
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(topics) { topic in
                            let isSelected = (selectedTopicId == topic.id)
                            let topicColor = colorFromHex(topic.iconColorHex)
                            Button {
                                onSelectTopic(topic)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: topic.isGeneral ? "number" : "bubble.left.fill")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(isSelected ? palette.onPrimary : topicColor)

                                    Text(topic.name)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                        .lineLimit(1)

                                    if topic.isClosed {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                            .opacity(0.75)
                                    }

                                    if topic.unreadCount > 0 {
                                        Text(topic.unreadCount > 99 ? "99+" : "\(topic.unreadCount)")
                                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(isSelected ? palette.onPrimary.opacity(0.24) : palette.primary.opacity(0.22))
                                            .foregroundColor(isSelected ? palette.onPrimary : palette.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                                .foregroundColor(isSelected ? palette.onPrimary : palette.onSurface)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .mgGlassCapsule(
                                    tint: isSelected ? palette.primary : palette.surfaceContainer.opacity(0.45),
                                    interactive: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(palette.surfaceContainerLow.opacity(0.75))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(palette.outlineVariant.opacity(0.2)),
            alignment: .bottom
        )
    }

    private func colorFromHex(_ hex: Int) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

private struct InChatSearchBar: View {
    @Binding var query: String
    let palette: MD3ColorPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField("Search messages in this chat...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .mgGlassCapsule(
            tint: palette.surfaceContainer.opacity(0.42),
            interactive: true
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private struct MessageFeedView: View {
    let messages: [Message]
    let selectedChatId: String?
    let scrollToMessageIdRequest: String?
    let isLoadingMessages: Bool
    let canLoadOlderMessages: Bool
    let isLoadingOlderMessages: Bool
    let downloadingMediaMessageId: String?
    let playingVoiceMessageId: String?
    let bookmarkedIds: Set<String>
    let bubbleCornerRadius: CGFloat
    let palette: MD3ColorPalette
    let onLoadOlder: () -> Void
    let onReply: (Message) -> Void
    let onReact: (String, String) -> Void
    let onOpenMedia: (Message) -> Void
    let onToggleVoice: (Message) -> Void
    let onToggleBookmark: (Message, Bool) -> Void

    /// Precomputes the first message ID of each consecutive date group in O(N)
    /// so `ForEach(messages)` uses stable identity without `Array(enumerated())`.
    private var firstMessageIdPerDateSection: Set<String> {
        var result = Set<String>()
        var previousDateGroup: String? = nil
        for msg in messages {
            if msg.dateGroup != previousDateGroup {
                result.insert(msg.id)
                previousDateGroup = msg.dateGroup
            }
        }
        return result
    }

    var body: some View {
        if isLoadingMessages && messages.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading messages...")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let sectionStartIds = firstMessageIdPerDateSection
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if canLoadOlderMessages {
                            Button(action: onLoadOlder) {
                                HStack(spacing: 6) {
                                    if isLoadingOlderMessages {
                                        ProgressView()
                                            .controlSize(.mini)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 12.5))
                                    }
                                    Text(isLoadingOlderMessages ? "Loading earlier messages..." : "Load earlier messages")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(palette.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .mgGlassCapsule(
                                    tint: palette.surfaceContainerHigh.opacity(0.45),
                                    interactive: true
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingOlderMessages)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }

                        ForEach(messages) { msg in
                            if sectionStartIds.contains(msg.id) {
                                Text(msg.dateGroup)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .mgGlassCapsule(tint: palette.surfaceContainerHigh.opacity(0.45))
                                    .padding(.vertical, 8)
                            }

                            MessageBubbleView(
                                message: msg,
                                palette: palette,
                                baseRadius: bubbleCornerRadius,
                                isDownloadingMedia: downloadingMediaMessageId == msg.id,
                                isPlayingVoice: playingVoiceMessageId == msg.id,
                                isBookmarked: bookmarkedIds.contains(msg.id),
                                onReply: onReply,
                                onReact: onReact,
                                onOpenMedia: onOpenMedia,
                                onToggleVoice: onToggleVoice,
                                onToggleBookmark: onToggleBookmark
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .clipped()
                .onChange(of: selectedChatId) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: messages.last?.id) { _, lastId in
                    if let lastId {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToMessageIdRequest) { _, targetId in
                    if let targetId {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

/// Renders rich Materialgram / Telegram chat wallpapers including vector doodle motifs,
/// multi-stop mesh gradients, cosmic starfields, and user-uploaded custom photo files
/// with configurable blur and background dimming.
public struct ConversationWallpaper: View {
    public let preset: WallpaperPreset
    public let customPhotoPath: String?
    public let blurRadius: Double
    public let dimming: Double
    public let showPattern: Bool
    public let palette: MD3ColorPalette

    public init(
        preset: WallpaperPreset,
        customPhotoPath: String? = nil,
        blurRadius: Double = 0,
        dimming: Double = 0.15,
        showPattern: Bool = true,
        palette: MD3ColorPalette
    ) {
        self.preset = preset
        self.customPhotoPath = customPhotoPath
        self.blurRadius = blurRadius
        self.dimming = dimming
        self.showPattern = showPattern
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                baseCanvas(size: geo.size)
                    .blur(radius: blurRadius)

                if showPattern && preset != .customPhoto {
                    TelegramMotifPatternOverlay(
                        opacity: preset == .telegramCats ? 0.11 : 0.055
                    )
                }

                if dimming > 0.005 {
                    Color.black.opacity(min(0.85, max(0, dimming)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private func baseCanvas(size: CGSize) -> some View {
        switch preset {
        case .tonal:
            ZStack {
                palette.surface
                LinearGradient(
                    colors: [
                        palette.primary.opacity(0.24),
                        palette.surfaceContainerLow.opacity(0.85),
                        palette.secondaryContainer.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [palette.primary.opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: max(size.width, size.height) * 0.75
                )
            }

        case .telegramCats:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.14, blue: 0.21),
                        Color(red: 0.14, green: 0.23, blue: 0.31),
                        Color(red: 0.10, green: 0.18, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.24, green: 0.56, blue: 0.78).opacity(0.25),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.8
                )
            }

        case .darkSpace:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.12),
                        Color(red: 0.11, green: 0.08, blue: 0.24),
                        Color(red: 0.05, green: 0.13, blue: 0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.48, green: 0.26, blue: 0.88).opacity(0.32),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.7
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.14, green: 0.58, blue: 0.86).opacity(0.24),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.65
                )
            }

        case .mintGradient:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.13, blue: 0.15),
                        Color(red: 0.06, green: 0.25, blue: 0.26),
                        Color(red: 0.08, green: 0.17, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.82, blue: 0.64).opacity(0.32),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 15,
                    endRadius: max(size.width, size.height) * 0.75
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.18, green: 0.56, blue: 0.92).opacity(0.24),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 15,
                    endRadius: max(size.width, size.height) * 0.75
                )
            }

        case .sunsetGlow:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.07, blue: 0.18),
                        Color(red: 0.28, green: 0.11, blue: 0.20),
                        Color(red: 0.34, green: 0.17, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.96, green: 0.44, blue: 0.24).opacity(0.34),
                        .clear
                    ],
                    center: .bottom,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.75
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.78, green: 0.24, blue: 0.58).opacity(0.26),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: max(size.width, size.height) * 0.7
                )
            }

        case .cleanMonochrome:
            Color.black

        case .customPhoto:
            #if os(macOS)
            if let path = customPhotoPath,
               !path.isEmpty,
               let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.14, blue: 0.21),
                        Color(red: 0.14, green: 0.23, blue: 0.31)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            #else
            palette.surface
            #endif
        }
    }
}

/// Vector tiled Telegram motif pattern (paperplanes, chat bubbles, stars, locks, sparkles)
/// rendered natively with SwiftUI `Canvas`.
private struct TelegramMotifPatternOverlay: View {
    let opacity: Double

    private static let symbols = [
        "paperplane",
        "bubble.left",
        "star",
        "sparkles",
        "lock",
        "heart",
        "bolt",
        "music.note"
    ]

    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 68
            let cols = Int(ceil(size.width / cell)) + 1
            let rows = Int(ceil(size.height / cell)) + 1

            for r in 0..<rows {
                for c in 0..<cols {
                    let idx = (r * 5 + c * 3) % Self.symbols.count
                    let symName = Self.symbols[idx]
                    let xOffset: CGFloat = (r % 2 == 0) ? 16 : 48
                    let pt = CGPoint(
                        x: CGFloat(c) * cell + xOffset,
                        y: CGFloat(r) * cell + 28
                    )
                    let text = Text(Image(systemName: symName))
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(opacity))
                    context.draw(text, at: pt, anchor: .center)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EmptyConversationPlaceholder: View {
    let isReady: Bool
    let palette: MD3ColorPalette
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            AethergramLogoView(size: 56)
            Text(isReady ? "No conversation selected. Pick a chat from the sidebar to jump in." : "Connect your Telegram account to load your chats.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if !isReady {
                Button("Sign In", action: onSignIn)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
            }
        }
        .padding(28)
        .mgGlassCard(cornerRadius: 22, tint: palette.surfaceContainerLow.opacity(0.4))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface)
    }
}
