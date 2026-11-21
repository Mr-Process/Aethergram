import Foundation

/// Manages up to 10 (standard) or 20 (Premium) isolated TDLib account sessions,
/// matching Materialgram's raised account limit (3/6 -> 10/20).
public struct AccountSessionSlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let databaseDirectory: URL
    public var displayName: String

    public init(id: String, databaseDirectory: URL, displayName: String) {
        self.id = id
        self.databaseDirectory = databaseDirectory
        self.displayName = displayName
    }
}

public enum AccountPoolError: Error, Sendable {
    case limitReached(maxAccounts: Int)
}

public struct AccountSessionPool: Sendable {
    public static let standardLimit = 10
    public static let premiumLimit = 20

    public let rootDirectory: URL
    public let isPremium: Bool
    public private(set) var slots: [AccountSessionSlot]

    public var maxSlots: Int {
        isPremium ? Self.premiumLimit : Self.standardLimit
    }

    public init(rootDirectory: URL = TDLibConfiguration.defaultSupportDirectory(), isPremium: Bool = false, slots: [AccountSessionSlot] = []) {
        self.rootDirectory = rootDirectory
        self.isPremium = isPremium
        self.slots = slots
    }

    public mutating func addSlot(accountId: String, displayName: String) throws -> AccountSessionSlot {
        if let existing = slots.first(where: { $0.id == accountId }) {
            return existing
        }
        guard slots.count < maxSlots else {
            throw AccountPoolError.limitReached(maxAccounts: maxSlots)
        }
        let safeId = accountId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let dbDir = rootDirectory.appendingPathComponent("tdlib_db_\(safeId)", isDirectory: true)
        let slot = AccountSessionSlot(id: accountId, databaseDirectory: dbDir, displayName: displayName)
        slots.append(slot)
        return slot
    }
}
