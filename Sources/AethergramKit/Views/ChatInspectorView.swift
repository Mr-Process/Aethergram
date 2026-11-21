import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct ChatInspectorView: View {
    @ObservedObject public var store: ChatStore
    public let chat: Chat
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    private let mediaGridColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    public init(store: ChatStore, chat: Chat, palette: MD3ColorPalette, onClose: @escaping () -> Void) {
        self.store = store
        self.chat = chat
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header & Close Button
                HStack {
                    Text("Chat Info")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.onSurface)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Avatar & Profile Title
                VStack(spacing: 8) {
                    MD3AvatarView(
                        localPath: chat.avatarLocalPath,
                        initials: chat.avatarInitials,
                        hue: chat.avatarHue,
                        size: 72
                    )

                    Text(chat.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.onSurface)
                        .multilineTextAlignment(.center)

                    if let username = chat.username, !username.isEmpty {
                        let handle = ProfileMetadataEstimator.formattedHandle(username)
                        Button {
                            ProfileMetadataEstimator.copyToClipboard(handle)
                        } label: {
                            HStack(spacing: 4) {
                                Text(handle)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(palette.primary)
                        }
                        .buttonStyle(.plain)
                    } else if let sub = chat.subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Live Actions
                HStack(spacing: 14) {
                    actionButton(icon: "magnifyingglass", label: "Search") {
                        store.showInChatSearch.toggle()
                    }
                    actionButton(icon: "doc.text.fill", label: "Export") {
                        store.showExportSheet = true
                    }
                    actionButton(icon: "shield.lefthalf.filled", label: "Admin") {
                        store.showGroupAdminSheet = true
                    }
                    actionButton(icon: "doc.on.doc", label: "Copy ID") {
                        ProfileMetadataEstimator.copyToClipboard(chat.id)
                    }
                }

                if let status = store.lastExportStatus {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(palette.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // Aethergram Profile Metadata (Wired to Advanced -> Aethergram toggles)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        AethergramLogoView(size: 16)
                        Text("\(AethergramBrand.appName) Details")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    infoRow(icon: "number", title: "Peer ID", value: chat.id)

                    if store.showRegistrationDate,
                       let regDate = ProfileMetadataEstimator.estimatedRegistrationDate(forPeerId: chat.id) {
                        infoRow(icon: "calendar", title: "Registration date", value: regDate)
                    }

                    if store.showDatacenterId {
                        let dcText = chat.datacenterId.map { "DC \($0)" } ?? "Production DC"
                        infoRow(icon: "server.rack", title: "Datacenter", value: dcText)
                    }

                    if store.showMaterialgramProfilePhotos {
                        infoRow(icon: "photo.on.rectangle", title: "Profile photos", value: "@gamee enabled")
                    }

                    infoRow(icon: "text.bubble", title: "Loaded messages", value: "\(store.messages.count)")
                }
                .padding(14)
                .background(palette.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Divider()

                sharedMediaSection

                Spacer()
            }
            .padding(16)
        }
        .frame(minWidth: 295, maxWidth: 335)
        .background(palette.surfaceContainerLow.opacity(0.6))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(palette.outlineVariant.opacity(0.3)),
            alignment: .leading
        )
        .task(id: chat.id) {
            await store.loadSharedMediaForActiveChat()
        }
    }

    // Shared Media Section with Separate Photos, Videos, Files, Voice & GIFs Tabs
    private var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shared Media")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(palette.onSurface)
                Spacer()
                if store.isLoadingSharedMedia {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Button {
                        Task { await store.loadSharedMediaForActiveChat() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Shared Media")
                }
            }

            sharedMediaTabBar

            sharedMediaContent
        }
    }

    private var sharedMediaTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SharedMediaTab.allCases) { tab in
                    sharedMediaTabButton(for: tab)
                }
            }
        }
    }

    private func sharedMediaTabButton(for tab: SharedMediaTab) -> some View {
        let isSelected = store.selectedSharedMediaTab == tab
        let count = store.sharedMediaMessages(for: tab).count
        return Button {
            store.selectedSharedMediaTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? palette.onPrimary.opacity(0.22) : palette.primary.opacity(0.16))
                        )
                        .foregroundColor(isSelected ? palette.onPrimary : palette.primary)
                }
            }
            .foregroundColor(isSelected ? palette.onPrimary : palette.onSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? palette.primary : palette.surfaceContainer)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sharedMediaContent: some View {
        let activeTab = store.selectedSharedMediaTab
        let currentItems = store.sharedMediaMessages(for: activeTab)
        if currentItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: activeTab.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(palette.primary.opacity(0.45))
                Text("No shared \(activeTab.rawValue.lowercased()) yet.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(palette.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if activeTab == .photos || activeTab == .videos || activeTab == .gifs {
            LazyVGrid(columns: mediaGridColumns, spacing: 6) {
                ForEach(currentItems) { msg in
                    SharedMediaGridCell(
                        message: msg,
                        tab: activeTab,
                        isBookmarked: store.isMessageBookmarked(msg.id),
                        palette: palette,
                        onOpen: { openMediaItem(msg) },
                        onJumpToMessage: { jumpToMediaMessage(msg) },
                        onToggleBookmark: { store.toggleBookmark(for: msg) }
                    )
                }
            }
        } else {
            VStack(spacing: 6) {
                ForEach(currentItems) { msg in
                    SharedMediaFileRow(
                        message: msg,
                        tab: activeTab,
                        isPlayingVoice: store.playingVoiceMessageId == msg.id,
                        palette: palette,
                        onPrimaryAction: { activateFileOrVoiceItem(msg, tab: activeTab) },
                        onJumpToMessage: { jumpToMediaMessage(msg) }
                    )
                }
            }
        }
    }

    private func openMediaItem(_ msg: Message) {
        Task { await store.openMediaViewer(for: msg) }
    }

    private func activateFileOrVoiceItem(_ msg: Message, tab: SharedMediaTab) {
        if tab == .voice {
            Task { await store.toggleVoiceNotePlayback(for: msg) }
        } else {
            Task { await store.openMediaViewer(for: msg) }
        }
    }

    private func jumpToMediaMessage(_ msg: Message) {
        if !store.messages.contains(where: { $0.id == msg.id }) {
            store.messages.insert(msg, at: 0)
        }
        store.scrollToMessageIdRequest = msg.id
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(palette.surfaceContainerHigh)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundColor(palette.primary)
                    )
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.onSurface)
            }
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(palette.primary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(palette.onSurface)

            Spacer()

            Text(value)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

private struct SharedMediaGridCell: View {
    let message: Message
    let tab: SharedMediaTab
    let isBookmarked: Bool
    let palette: MD3ColorPalette
    let onOpen: () -> Void
    let onJumpToMessage: () -> Void
    let onToggleBookmark: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack {
                #if os(macOS)
                if let img = previewImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 86)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(palette.surfaceContainerHigh)
                        .frame(width: 86, height: 86)
                        .overlay(
                            Image(systemName: tab.iconName)
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        )
                }
                #endif

                if tab == .videos || tab == .gifs {
                    Color.black.opacity(0.22)
                    Image(systemName: tab == .gifs ? "sparkles.tv" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.5)))

                    if let dur = message.media?.duration, dur > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(dur))
                                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.black.opacity(0.65)))
                                    .padding(4)
                            }
                        }
                    }
                }
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.outlineVariant.opacity(0.28), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onOpen) {
                Label(tab == .videos ? "Play Video" : "View Media", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            Button(action: onJumpToMessage) {
                Label("Show in Chat", systemImage: "arrow.right.circle")
            }
            Button(action: onToggleBookmark) {
                Label(isBookmarked ? "Remove Bookmark" : "Bookmark", systemImage: isBookmarked ? "bookmark.slash.fill" : "bookmark.fill")
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    #if os(macOS)
    private var previewImage: NSImage? {
        guard let media = message.media else { return nil }
        if media.kind == .photo, let p = media.localPath, !p.isEmpty, let img = NSImage(contentsOfFile: p) {
            return img
        }
        if let tp = media.thumbnailLocalPath, !tp.isEmpty, let img = NSImage(contentsOfFile: tp) {
            return img
        }
        if let mini = media.minithumbnailBase64, !mini.isEmpty,
           let data = Data(base64Encoded: mini),
           let img = NSImage(data: data) {
            return img
        }
        return nil
    }
    #endif
}

private struct SharedMediaFileRow: View {
    let message: Message
    let tab: SharedMediaTab
    let isPlayingVoice: Bool
    let palette: MD3ColorPalette
    let onPrimaryAction: () -> Void
    let onJumpToMessage: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrimaryAction) {
                Circle()
                    .fill(palette.primary.opacity(0.16))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: tab == .voice ? (isPlayingVoice ? "stop.fill" : "play.fill") : "doc.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(palette.primary)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.onSurface)
                    .lineLimit(1)
                Text("\(message.dateGroup) · \(message.timestamp)")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Button(action: onJumpToMessage) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Chat")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(palette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var titleText: String {
        if tab == .voice {
            let dur = message.media?.duration ?? 0
            return "Voice message (\(dur)s)"
        }
        return message.media?.fileName ?? (message.text.isEmpty ? "Document" : message.text)
    }
}
