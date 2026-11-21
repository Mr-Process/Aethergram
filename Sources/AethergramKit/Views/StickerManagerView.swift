import SwiftUI

public struct StickerSetSummary: Identifiable, Hashable, Sendable {
    public let id: Int64
    public let title: String
    public let name: String
    public let stickerCount: Int
    public let isInstalled: Bool

    public var authorId: Int64 {
        StickerSetHelper.authorId(fromSetId: id)
    }

    public init(id: Int64, title: String, name: String, stickerCount: Int, isInstalled: Bool = true) {
        self.id = id
        self.title = title
        self.name = name
        self.stickerCount = stickerCount
        self.isInstalled = isInstalled
    }
}

public enum StickerSetHelper {
    /// Extracts the sticker set author's Telegram user ID from the 64-bit sticker set ID
    /// (matching Materialgram's "Ability to copy the sticker set author's id").
    public static func authorId(fromSetId setId: Int64) -> Int64 {
        return setId >> 32
    }
}

/// Sticker pack manager matching Materialgram's sticker pack menu:
/// displays sticker counts, replaces "Share stickers" with "Remove", and allows copying author ID.
public struct StickerManagerView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    public init(store: ChatStore, palette: MD3ColorPalette, onClose: @escaping () -> Void) {
        self.store = store
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sticker Sets")
                        .font(.mgFont(size: 16, weight: .bold))
                    Text("Manage installed Telegram sticker packs and copy author IDs.")
                        .font(.mgFont(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    Task { await store.loadInstalledStickerSets() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
            }

            if store.installedStickerSets.isEmpty {
                Text("No sticker sets loaded. Sign in to Telegram and click Refresh to fetch your installed packs.")
                    .font(.mgFont(size: 12))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.installedStickerSets) { pack in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(pack.title)
                                            .font(.mgFont(size: 13, weight: .semibold))
                                        Text("\(pack.stickerCount) stickers")
                                            .font(.mgFont(size: 10.5, weight: .medium))
                                            .foregroundColor(palette.primary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(palette.primary.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    Text("Author ID: \(pack.authorId)")
                                        .font(.mgFont(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Copy author ID") {
                                    ProfileMetadataEstimator.copyToClipboard(String(pack.authorId))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Button("Remove") {
                                    Task { await store.removeStickerSet(setId: pack.id) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(palette.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 400)
        .background(palette.surface)
    }
}
