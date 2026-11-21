import SwiftUI
#if os(macOS)
import AppKit
#endif

/// iMe-inspired Bookmarks & Cloud Albums sheet for messages, photos, videos, and files.
public struct BookmarksSheetView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    public init(store: ChatStore, palette: MD3ColorPalette, onClose: @escaping () -> Void) {
        self.store = store
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BookmarksHeaderBar(
                totalCount: store.bookmarks.count,
                currentChatTitle: store.selectedChat?.title,
                currentChatOnly: $store.bookmarkCurrentChatOnly,
                palette: palette,
                onClose: onClose
            )

            BookmarksCategoryStrip(
                selectedCategory: store.selectedBookmarkCategory,
                countProvider: { store.bookmarkCount(for: $0) },
                palette: palette,
                onSelectCategory: { store.selectedBookmarkCategory = $0 }
            )

            BookmarksSearchBar(
                query: $store.bookmarkSearchQuery,
                palette: palette
            )

            if let status = store.bookmarkStatusMessage {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundColor(palette.primary)
                    Text(status)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(palette.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            let items = store.filteredBookmarks
            if items.isEmpty {
                EmptyBookmarksPlaceholder(
                    category: store.selectedBookmarkCategory,
                    palette: palette
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            BookmarkRowCard(
                                item: item,
                                palette: palette,
                                onOpenMedia: {
                                    Task { await store.openBookmarkedMedia(item) }
                                },
                                onJumpToChat: {
                                    Task { await store.jumpToBookmark(item) }
                                },
                                onSyncCloud: {
                                    Task { await store.forwardBookmarkToTelegramCloud(item) }
                                },
                                onRemove: {
                                    store.removeBookmark(item)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 640, idealWidth: 700, minHeight: 520, idealHeight: 580)
        .background(palette.surface)
    }
}

private struct BookmarksHeaderBar: View {
    let totalCount: Int
    let currentChatTitle: String?
    @Binding var currentChatOnly: Bool
    let palette: MD3ColorPalette
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(palette.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Bookmarks & Cloud Albums")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(palette.onSurface)
                Text("Saved messages, photos, and videos (\(totalCount) total)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let currentChatTitle {
                Toggle("Only \(currentChatTitle)", isOn: $currentChatOnly)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }

            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(palette.primary)
                .controlSize(.small)
        }
    }
}

private struct BookmarksCategoryStrip: View {
    let selectedCategory: BookmarkCategory
    let countProvider: (BookmarkCategory) -> Int
    let palette: MD3ColorPalette
    let onSelectCategory: (BookmarkCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LiquidGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(BookmarkCategory.allCases) { cat in
                        let isSelected = selectedCategory == cat
                        let count = countProvider(cat)
                        Button {
                            onSelectCategory(cat)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(cat.rawValue)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(isSelected ? palette.onPrimary.opacity(0.22) : palette.primary.opacity(0.18))
                                        .foregroundColor(isSelected ? palette.onPrimary : palette.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            .foregroundColor(isSelected ? palette.onPrimary : palette.onSurface)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .mgGlassCapsule(
                                tint: isSelected ? palette.primary : palette.surfaceContainer.opacity(0.45),
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct BookmarksSearchBar: View {
    @Binding var query: String
    let palette: MD3ColorPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)

            TextField("Search bookmarked messages, photos, videos, or chats...", text: $query)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .mgGlassCapsule(
            tint: palette.surfaceContainer.opacity(0.4),
            interactive: true
        )
    }
}

private struct BookmarkRowCard: View {
    let item: BookmarkItem
    let palette: MD3ColorPalette
    let onOpenMedia: () -> Void
    let onJumpToChat: () -> Void
    let onSyncCloud: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Media Preview Thumbnail (for Photo / Video / Document Bookmarks)
            if item.category == .photo || item.category == .video {
                Button(action: onOpenMedia) {
                    ZStack {
                        #if os(macOS)
                        if let img = previewImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 112, height: 84)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(palette.surfaceContainerHigh)
                                .frame(width: 112, height: 84)
                                .overlay(
                                    Image(systemName: item.category == .video ? "video.fill" : "photo.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                )
                        }
                        #endif

                        if item.category == .video {
                            Color.black.opacity(0.24)
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .mgGlassCircle(tint: Color.black.opacity(0.45), interactive: true)
                        }
                    }
                    .frame(width: 112, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(palette.primary)

                    Text(item.chatTitle)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(palette.primary)
                        .lineLimit(1)

                    if let tName = item.topicName, !tName.isEmpty {
                        Text("· #\(tName)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("· \(item.senderName)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(item.dateGroup) \(item.timestamp)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(.secondary)
                }

                if !item.text.isEmpty {
                    Text(item.text)
                        .font(.system(size: 13))
                        .foregroundColor(palette.onSurface)
                        .lineLimit(3)
                        .textSelection(.enabled)
                } else if let media = item.reconstructedMedia {
                    let info = [
                        media.kind.rawValue.capitalized,
                        media.duration > 0 ? media.formattedDuration : nil,
                        !media.formattedFileSize.isEmpty ? media.formattedFileSize : nil
                    ].compactMap { $0 }.joined(separator: " · ")
                    Text(info)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if item.category == .photo || item.category == .video {
                        Button(action: onOpenMedia) {
                            Label(item.category == .video ? "Play Video" : "View Photo", systemImage: item.category == .video ? "play.fill" : "eye.fill")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .controlSize(.small)
                    }

                    Button(action: onJumpToChat) {
                        Label("Jump to Chat", systemImage: "arrow.up.right.circle")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: onSyncCloud) {
                        Label("Save to Telegram Cloud", systemImage: "icloud.and.arrow.up")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Forward this item to your Telegram Saved Messages cloud")

                    Spacer()

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Bookmark")
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(palette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.outlineVariant.opacity(0.28), lineWidth: 0.75)
        )
    }

    #if os(macOS)
    private var previewImage: NSImage? {
        if let p = item.mediaLocalPath, !p.isEmpty, let img = NSImage(contentsOfFile: p) {
            return img
        }
        if let tp = item.thumbnailLocalPath, !tp.isEmpty, let img = NSImage(contentsOfFile: tp) {
            return img
        }
        if let mini = item.minithumbnailBase64, !mini.isEmpty,
           let data = Data(base64Encoded: mini),
           let img = NSImage(data: data) {
            return img
        }
        return nil
    }
    #endif
}

private struct EmptyBookmarksPlaceholder: View {
    let category: BookmarkCategory
    let palette: MD3ColorPalette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 40))
                .foregroundColor(palette.primary.opacity(0.5))
            Text("No \(category == .all ? "" : category.rawValue.lowercased() + " ")bookmarks yet.")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundColor(palette.onSurface)
            Text("Nothing saved here yet. Bookmark a message, photo, or video from any chat to keep it close.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(palette.surfaceContainerLow.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
