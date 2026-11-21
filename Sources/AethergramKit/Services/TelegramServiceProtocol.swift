import Foundation

public protocol TelegramServiceProtocol: Actor {
    func fetchFolders() async throws -> [Folder]
    func fetchChats(in folderId: String) async throws -> [Chat]
    func fetchMessages(for chatId: String) async throws -> [Message]
    func sendMessage(chatId: String, text: String, replyTo: String?) async throws -> Message
    func toggleReaction(messageId: String, emoji: String, in chatId: String) async throws -> [Reaction]
    func markAsRead(chatId: String) async throws
}
