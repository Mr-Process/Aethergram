import SwiftUI

public struct ChatEventLogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let date: String
    public let summary: String

    public init(id: String, date: String, summary: String) {
        self.id = id
        self.date = date
        self.summary = summary
    }
}

public enum GroupMentionHelper {
    /// Formats multiple usernames into a single space-separated `@mention` string
    /// (matching Materialgram's "Ability to mention multiple users at once").
    public static func formatMultiMention(_ handles: [String]) -> String {
        handles
            .map { ProfileMetadataEstimator.formattedHandle($0) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Group admin menu, Recent Actions chat log, live online counter, and multi-mention helper.
public struct GroupAdminToolsView: View {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Admin Tools - \(chat.title)")
                        .font(.mgFont(size: 16, weight: .bold))
                    Text("Online members: \(store.activeChatOnlineCount) • Recent Actions log")
                        .font(.mgFont(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Load chat log") {
                    Task { await store.loadChatEventLog(chatId: chat.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
            }

            if store.chatEventLog.isEmpty {
                Text("No recent admin events loaded. Click Load chat log to query TDLib getChatEventLog.")
                    .font(.mgFont(size: 12))
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.chatEventLog) { entry in
                            HStack {
                                Text(entry.summary)
                                    .font(.mgFont(size: 12.5))
                                Spacer()
                                Text(entry.date)
                                    .font(.mgFont(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(palette.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 380)
        .background(palette.surface)
    }
}
