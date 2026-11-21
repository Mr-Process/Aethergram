import SwiftUI

public struct MainSplitView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject public var store: ChatStore

    private var palette: MD3ColorPalette {
        MD3ColorPalette.forPreset(store.palettePreset, isDark: colorScheme == .dark)
    }

    public init(store: ChatStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarColumnView(
                    accounts: store.accounts,
                    activeAccount: store.activeAccount,
                    authDisplayText: store.tdlibAuthState.displayText,
                    folders: store.folders,
                    selectedFolderId: store.selectedFolderId,
                    isProxyEnabled: store.isProxyEnabled,
                    isPasscodeEnabled: store.passcodeManager.isPasscodeEnabled,
                    bookmarkCount: store.bookmarks.count,
                    palette: palette,
                    onSwitchAccount: { store.switchAccount($0) },
                    onOpenAccountSettings: openAccountSettings,
                    onSelectFolder: selectFolder,
                    onOpenProxy: { store.showProxySheet = true },
                    onOpenBookmarks: { store.showBookmarksSheet = true },
                    onLockNow: lockNow,
                    onOpenSettings: { store.showSettingsSheet = true }
                )
                .navigationSplitViewColumnWidth(min: 224, ideal: 244, max: 280)
            } content: {
                ChatListColumnView(
                    searchText: $store.searchText,
                    chats: store.filteredChats,
                    selectedChatId: store.selectedChatId,
                    compactMode: store.compactMode,
                    ghostMode: store.ghostMode,
                    palette: palette,
                    onSelectChat: selectChat
                )
                .navigationSplitViewColumnWidth(min: 285, ideal: 320, max: 390)
            } detail: {
                ConversationView(store: store, palette: palette)
            }
            .task {
                await store.loadInitialData()
            }
            .sheet(isPresented: $store.showSettingsSheet) {
                AethergramSettingsView(store: store, palette: palette)
            }
            .sheet(isPresented: $store.showProxySheet) {
                ProxySettingsView(store: store, palette: palette)
            }
            .sheet(isPresented: $store.showStickerManagerSheet) {
                StickerManagerView(store: store, palette: palette) {
                    store.showStickerManagerSheet = false
                }
            }
            .sheet(isPresented: $store.showGroupAdminSheet) {
                if let chat = store.selectedChat {
                    GroupAdminToolsView(store: store, chat: chat, palette: palette) {
                        store.showGroupAdminSheet = false
                    }
                }
            }
            .sheet(item: $store.activeMediaViewerItem) { item in
                if let controller = store.activeMediaController {
                    MediaViewerView(
                        item: item,
                        controller: controller,
                        palette: palette,
                        provider: store.tdlibProvider,
                        isBookmarked: store.isMessageBookmarked(item.id),
                        onToggleBookmark: {
                            if let msg = store.messages.first(where: { $0.id == item.id }) {
                                store.toggleBookmark(for: msg)
                            } else if let bm = store.bookmarks.first(where: { $0.messageId == item.id }) {
                                store.removeBookmark(bm)
                            }
                        },
                        onDownloadedPath: { path in
                            store.updateMessageMediaLocalPath(messageId: item.id, path: path)
                        }
                    ) {
                        controller.cleanup(provider: store.tdlibProvider)
                        store.activeMediaViewerItem = nil
                        store.activeMediaController = nil
                    }
                }
            }
            .sheet(isPresented: $store.showBookmarksSheet) {
                BookmarksSheetView(store: store, palette: palette) {
                    store.showBookmarksSheet = false
                }
            }
            .sheet(isPresented: $store.showExportSheet) {
                ChatExportSheetView(
                    store: store,
                    controller: store.exportController,
                    palette: palette
                ) {
                    store.showExportSheet = false
                }
            }
            .sheet(item: Binding(
                get: { store.activePhotoEditURL.map { IdentifiableURL(url: $0) } },
                set: { if $0 == nil { store.activePhotoEditURL = nil } }
            )) { identifiable in
                PhotoEditorView(
                    controller: store.photoEditorController,
                    sourceURL: identifiable.url,
                    palette: palette,
                    onCancel: {
                        store.activePhotoEditURL = nil
                    },
                    onSendEdited: { editedURL in
                        Task {
                            await store.sendEditedPhoto(url: editedURL)
                        }
                    }
                )
            }
            .sheet(item: Binding(
                get: { store.activeMiniAppURL.map { IdentifiableURL(url: $0) } },
                set: { if $0 == nil { store.activeMiniAppURL = nil } }
            )) { identifiable in
                MiniAppSheetView(
                    title: store.selectedChat?.title ?? "Mini App",
                    url: identifiable.url,
                    palette: palette
                ) {
                    store.activeMiniAppURL = nil
                }
            }

            if store.passcodeManager.isLocked {
                PasscodeLockView(passcodeManager: store.passcodeManager, palette: palette)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
    }

    private func openAccountSettings() {
        store.selectedSettingsSection = .myAccount
        store.showSettingsSheet = true
    }

    private func selectFolder(_ id: String) {
        Task {
            await store.selectFolder(id: id)
        }
    }

    private func selectChat(_ id: String) {
        Task {
            await store.selectChat(id: id)
        }
    }

    private func lockNow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.passcodeManager.lockNow()
        }
    }
}

// MARK: - Column 1 Subviews (SidebarAccountCard, FolderRailView, SidebarFooterBar)

private struct SidebarColumnView: View {
    let accounts: [UserAccount]
    let activeAccount: UserAccount?
    let authDisplayText: String
    let folders: [Folder]
    let selectedFolderId: String
    let isProxyEnabled: Bool
    let isPasscodeEnabled: Bool
    let bookmarkCount: Int
    let palette: MD3ColorPalette
    let onSwitchAccount: (String) -> Void
    let onOpenAccountSettings: () -> Void
    let onSelectFolder: (String) -> Void
    let onOpenProxy: () -> Void
    let onOpenBookmarks: () -> Void
    let onLockNow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Aethergram Brand Header
            HStack(spacing: 10) {
                AethergramLogoView(size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(AethergramBrand.appName)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(palette.onSurface)
                    Text("Liquid Glass")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(palette.primary)
                }
                Spacer()
                Text("v\(AethergramBrand.version)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.surfaceContainer.opacity(0.6))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            SidebarAccountCard(
                accounts: accounts,
                activeAccount: activeAccount,
                authDisplayText: authDisplayText,
                palette: palette,
                onSwitchAccount: onSwitchAccount,
                onOpenAccountSettings: onOpenAccountSettings
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.35)

            FolderRailView(
                folders: folders,
                selectedFolderId: selectedFolderId,
                palette: palette,
                onSelectFolder: onSelectFolder
            )

            Divider()
                .opacity(0.35)

            SidebarFooterBar(
                isProxyEnabled: isProxyEnabled,
                isPasscodeEnabled: isPasscodeEnabled,
                bookmarkCount: bookmarkCount,
                palette: palette,
                onOpenProxy: onOpenProxy,
                onOpenBookmarks: onOpenBookmarks,
                onLockNow: onLockNow,
                onOpenSettings: onOpenSettings
            )
        }
        .background(
            LinearGradient(
                colors: [
                    palette.surfaceContainerLow,
                    palette.surface.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct SidebarAccountCard: View {
    let accounts: [UserAccount]
    let activeAccount: UserAccount?
    let authDisplayText: String
    let palette: MD3ColorPalette
    let onSwitchAccount: (String) -> Void
    let onOpenAccountSettings: () -> Void

    var body: some View {
        if let acc = activeAccount {
            Menu {
                ForEach(accounts) { item in
                    Button {
                        onSwitchAccount(item.id)
                    } label: {
                        HStack {
                            Text(item.name)
                            if item.isActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("Account Settings...", action: onOpenAccountSettings)
            } label: {
                HStack(spacing: 10) {
                    MD3AvatarView(
                        localPath: acc.avatarLocalPath,
                        initials: acc.avatarInitials,
                        hue: acc.avatarHue,
                        size: 36
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(acc.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(palette.onSurface)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(acc.username.isEmpty ? "Telegram account" : acc.username)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .mgGlassCard(
                    cornerRadius: 14,
                    tint: palette.surfaceContainer.opacity(0.45),
                    interactive: true
                )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onOpenAccountSettings) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(palette.primary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(palette.primary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign in to Telegram")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(palette.onSurface)
                            .lineLimit(1)
                        Text(authDisplayText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .mgGlassCard(
                    cornerRadius: 14,
                    tint: palette.surfaceContainer.opacity(0.45),
                    interactive: true
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FolderRailView: View {
    let folders: [Folder]
    let selectedFolderId: String
    let palette: MD3ColorPalette
    let onSelectFolder: (String) -> Void

    var body: some View {
        ScrollView {
            LiquidGlassContainer(spacing: 5) {
                LazyVStack(spacing: 5) {
                    ForEach(folders) { folder in
                        let isSelected = selectedFolderId == folder.id
                        Button {
                            onSelectFolder(folder.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: folder.iconName)
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? palette.primary : .secondary)
                                    .frame(width: 22)

                                Text(folder.name)
                                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? palette.onSurface : palette.onSurface.opacity(0.84))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                if folder.badgeCount > 0 {
                                    MD3Badge(
                                        count: folder.badgeCount,
                                        color: palette.primary,
                                        onColor: palette.onPrimary
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(palette.primary.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(palette.primary.opacity(0.32), lineWidth: 0.75)
                                        )
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
        .clipped()
    }
}

private struct SidebarFooterBar: View {
    let isProxyEnabled: Bool
    let isPasscodeEnabled: Bool
    let bookmarkCount: Int
    let palette: MD3ColorPalette
    let onOpenProxy: () -> Void
    let onOpenBookmarks: () -> Void
    let onLockNow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        LiquidGlassContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onOpenProxy) {
                    Image(systemName: isProxyEnabled ? "shield.fill" : "shield")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(isProxyEnabled ? .green : .secondary)
                        .frame(width: 32, height: 32)
                        .mgGlassCircle(
                            tint: isProxyEnabled ? Color.green.opacity(0.18) : palette.surfaceContainer.opacity(0.35),
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
                .help("Proxy Settings")

                Button(action: onOpenBookmarks) {
                    Image(systemName: bookmarkCount > 0 ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(bookmarkCount > 0 ? palette.primary : .secondary)
                        .frame(width: 32, height: 32)
                        .mgGlassCircle(
                            tint: bookmarkCount > 0 ? palette.primary.opacity(0.18) : palette.surfaceContainer.opacity(0.35),
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
                .help("Bookmarks & Cloud Albums (\(bookmarkCount))")

                if isPasscodeEnabled {
                    Button(action: onLockNow) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .mgGlassCircle(
                                tint: palette.surfaceContainer.opacity(0.35),
                                interactive: true
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Lock \(AethergramBrand.appName) (⌘L)")
                }

                Spacer()

                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13))
                        Text("Settings")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(palette.onSurface)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .mgGlassCapsule(
                        tint: palette.surfaceContainer.opacity(0.42),
                        interactive: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Column 2 Subviews (ChatListSearchHeader, ChatRowView)

private struct ChatListColumnView: View {
    @Binding var searchText: String
    let chats: [Chat]
    let selectedChatId: String?
    let compactMode: Bool
    let ghostMode: Bool
    let palette: MD3ColorPalette
    let onSelectChat: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ChatListSearchHeader(searchText: $searchText, palette: palette)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.surface)

            Divider()
                .opacity(0.35)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(chats) { chat in
                        ChatRowView(
                            chat: chat,
                            isSelected: selectedChatId == chat.id,
                            compactMode: compactMode,
                            ghostMode: ghostMode,
                            palette: palette,
                            onSelect: { onSelectChat(chat.id) }
                        )
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .clipped()
        }
        .background(palette.surface)
    }
}

private struct ChatListSearchHeader: View {
    @Binding var searchText: String
    let palette: MD3ColorPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search chats...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
            tint: palette.surfaceContainer.opacity(0.38),
            interactive: true
        )
    }
}

private struct ChatRowView: View {
    let chat: Chat
    let isSelected: Bool
    let compactMode: Bool
    let ghostMode: Bool
    let palette: MD3ColorPalette
    let onSelect: () -> Void

    private var avatarSize: CGFloat {
        compactMode ? 38 : 44
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 11) {
                ZStack(alignment: .bottomTrailing) {
                    MD3AvatarView(
                        localPath: chat.avatarLocalPath,
                        initials: chat.avatarInitials,
                        hue: chat.avatarHue,
                        size: avatarSize
                    )

                    if chat.isOnline && !ghostMode {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(palette.surface, lineWidth: 2))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if chat.isForum || chat.isDirectMessagesGroup {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? palette.primary : .secondary)
                        } else if chat.type == .channel {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? palette.primary : .secondary)
                        } else if chat.type == .group {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? palette.primary : .secondary)
                        }

                        Text(chat.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(palette.onSurface)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 4)

                        Text(chat.lastMessageTime)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(isSelected ? palette.primary : .secondary)
                            .fixedSize()
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Text(chat.lastMessagePreview)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(compactMode ? 1 : 2)
                            .truncationMode(.tail)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        if chat.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        if chat.unreadCount > 0 {
                            MD3Badge(
                                count: chat.unreadCount,
                                isMuted: chat.isMuted,
                                color: palette.primary,
                                onColor: palette.onPrimary
                            )
                            .fixedSize()
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compactMode ? 7 : 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.primary.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(palette.primary.opacity(0.32), lineWidth: 0.75)
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
