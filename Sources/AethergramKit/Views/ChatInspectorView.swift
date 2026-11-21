import SwiftUI

public struct ChatInspectorView: View {
    @ObservedObject public var store: ChatStore
    public let chat: Chat
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    public init(store: ChatStore, chat: Chat, palette: MD3ColorPalette, onClose: @escaping () -> Void) {
        self.store = store
        self.chat = chat
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
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

                Spacer()
            }
            .padding(16)
        }
        .frame(minWidth: 260, maxWidth: 300)
        .background(palette.surfaceContainerLow.opacity(0.6))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(palette.outlineVariant.opacity(0.3)),
            alignment: .leading
        )
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
