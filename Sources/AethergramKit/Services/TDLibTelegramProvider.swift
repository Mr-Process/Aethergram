import Foundation

public enum TDLibAuthState: Equatable, Sendable {
    case unconfigured
    case connecting
    case waitPhoneNumber
    case waitCode
    case waitPassword(hint: String)
    case ready
    case error(String)

    public var displayText: String {
        switch self {
        case .unconfigured: return "Not connected"
        case .connecting: return "Connecting to Telegram MTProto..."
        case .waitPhoneNumber: return "Awaiting phone number"
        case .waitCode: return "Awaiting verification code"
        case .waitPassword(let hint): return hint.isEmpty ? "Awaiting 2FA password" : "Awaiting 2FA password (Hint: \(hint))"
        case .ready: return "Connected to live Telegram"
        case .error(let msg): return msg
        }
    }
}

public struct TDLibFileProgress: Equatable, Sendable {
    public let fileId: Int32
    public let localPath: String?
    public let downloadedSize: Int64
    public let expectedSize: Int64
    public let isCompleted: Bool
    public let isDownloading: Bool

    public init(
        fileId: Int32,
        localPath: String?,
        downloadedSize: Int64,
        expectedSize: Int64,
        isCompleted: Bool,
        isDownloading: Bool
    ) {
        self.fileId = fileId
        self.localPath = localPath
        self.downloadedSize = downloadedSize
        self.expectedSize = expectedSize
        self.isCompleted = isCompleted
        self.isDownloading = isDownloading
    }

    public var fractionCompleted: Double {
        guard expectedSize > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(downloadedSize) / Double(expectedSize)))
    }
}

public struct TDLibAuthResult: Equatable, Sendable {
    public let state: TDLibAuthState
    public let errorMessage: String?

    public init(state: TDLibAuthState, errorMessage: String? = nil) {
        self.state = state
        self.errorMessage = errorMessage
    }
}

public struct TDLibConfiguration: Sendable {
    public let apiId: Int
    public let apiHash: String
    public let databaseDirectory: URL
    public let useTestDc: Bool

    public init(
        apiId: Int,
        apiHash: String,
        databaseDirectory: URL,
        useTestDc: Bool = false
    ) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.databaseDirectory = databaseDirectory
        self.useTestDc = useTestDc
    }

    public static func defaultSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("Materialgram", isDirectory: true)
    }

    public static func loadFromEnvironmentOrDisk(databaseDirectory: URL? = nil) -> TDLibConfiguration? {
        let supportDir = defaultSupportDirectory()
        let dbDir = databaseDirectory ?? supportDir.appendingPathComponent("tdlib_db", isDirectory: true)

        if let idStr = ProcessInfo.processInfo.environment["TELEGRAM_API_ID"],
           let id = Int(idStr),
           let hash = ProcessInfo.processInfo.environment["TELEGRAM_API_HASH"],
           !hash.isEmpty {
            return TDLibConfiguration(apiId: id, apiHash: hash, databaseDirectory: dbDir)
        }

        let configFile = supportDir.appendingPathComponent("tdlib_config.json")
        guard let data = try? Data(contentsOf: configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["api_id"] as? Int,
              let hash = json["api_hash"] as? String,
              !hash.isEmpty else {
            return nil
        }
        return TDLibConfiguration(apiId: id, apiHash: hash, databaseDirectory: dbDir)
    }
}

/// Live TDLib-backed `TelegramServiceProtocol` implementation.
/// All folders, chats, messages, accounts, and proxies are fetched directly from `libtdjson.dylib`.
public actor TDLibTelegramProvider: TelegramServiceProtocol {
    public nonisolated let client: TDLibClient
    public nonisolated let tdlibVersion: String
    private nonisolated let isModernTDLib: Bool
    private var activeConfig: TDLibConfiguration?
    public private(set) var authState: TDLibAuthState = .unconfigured
    private var userNameCache: [Int64: String] = [:]
    private var chatNameCache: [Int64: String] = [:]
    private var directMessageTopicsCache: [Int64: [Int64: ForumTopic]] = [:]
    private var cachedFolders: [Folder] = [
        Folder(id: "all", name: "All Chats", iconName: "bubble.left.and.bubble.right.fill", badgeCount: 0)
    ]

    public init() throws {
        let tdClient = try TDLibClient()
        _ = try? tdClient.execute(["@type": "setLogVerbosityLevel", "new_verbosity_level": 1])
        self.client = tdClient
        let version = try tdClient.queryVersion()
        self.tdlibVersion = version
        let parts = version.split(separator: ".").compactMap { Int($0) }
        if parts.count >= 3 {
            self.isModernTDLib = (parts[0] > 1) || (parts[0] == 1 && parts[1] > 8) || (parts[0] == 1 && parts[1] == 8 && parts[2] >= 6)
        } else {
            self.isModernTDLib = true
        }
    }

    // MARK: - Live JSON-RPC Helper
    private func handlePassiveUpdate(_ msg: [String: Any]) throws {
        guard let type = msg["@type"] as? String else { return }
        if type == "updateChatFolders", let folders = msg["chat_folders"] as? [[String: Any]] {
            var updated: [Folder] = [
                Folder(id: "all", name: "All Chats", iconName: "bubble.left.and.bubble.right.fill", badgeCount: 0)
            ]
            for f in folders {
                let fid = (f["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
                let title: String
                if let nameObj = f["name"] as? [String: Any],
                   let textObj = nameObj["text"] as? [String: Any],
                   let t = textObj["text"] as? String, !t.isEmpty {
                    title = t
                } else if let t = f["title"] as? String, !t.isEmpty {
                    title = t
                } else {
                    title = "Folder"
                }
                updated.append(Folder(id: fid, name: title, iconName: "folder.fill", badgeCount: 0))
            }
            cachedFolders = updated
        } else if type == "updateChatFilters", let filters = msg["chat_filters"] as? [[String: Any]] {
            var updated: [Folder] = [
                Folder(id: "all", name: "All Chats", iconName: "bubble.left.and.bubble.right.fill", badgeCount: 0)
            ]
            for f in filters {
                let fid = (f["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
                let title = f["title"] as? String ?? "Folder"
                updated.append(Folder(id: fid, name: title, iconName: "folder.fill", badgeCount: 0))
            }
            cachedFolders = updated
        } else if type == "updateDirectMessagesChatTopic",
                  let topicObj = msg["topic"] as? [String: Any],
                  let cid = (topicObj["chat_id"] as? NSNumber)?.int64Value,
                  let tid = (topicObj["id"] as? NSNumber)?.int64Value {
            let lastMsg = topicObj["last_message"] as? [String: Any]
            let preview = Self.extractPreviewText(lastMsg)
            let ts = Self.formatTimestamp(lastMsg?["date"] as? Int ?? 0)
            let unread = topicObj["unread_count"] as? Int ?? 0
            let name = resolveSenderName(for: ["sender_id": topicObj["sender_id"] ?? [:]], isOutgoing: false)
            let item = ForumTopic(
                id: tid,
                chatId: String(cid),
                name: name.isEmpty ? "Topic \(tid)" : name,
                iconColorHex: 0x6FB9F0,
                isGeneral: false,
                isPinned: false,
                isClosed: false,
                unreadCount: unread,
                lastMessagePreview: preview,
                lastMessageTime: ts,
                isDirectMessageTopic: true
            )
            var map = directMessageTopicsCache[cid] ?? [:]
            map[tid] = item
            directMessageTopicsCache[cid] = map
        } else if type == "updateAuthorizationState",
                  let authObj = msg["authorization_state"] as? [String: Any] {
            try applyAuthStateObject(authObj)
        } else if type.hasPrefix("authorizationState") {
            try applyAuthStateObject(msg)
        }
    }

    @discardableResult
    private func applyAuthStateObject(_ authObj: [String: Any]) throws -> Bool {
        guard let stateType = authObj["@type"] as? String else { return false }
        switch stateType {
        case "authorizationStateWaitTdlibParameters":
            if let cfg = activeConfig {
                try configureParameters(cfg)
            }
            return false
        case "authorizationStateWaitEncryptionKey":
            try client.send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
            return false
        case "authorizationStateWaitPhoneNumber":
            authState = .waitPhoneNumber
            return true
        case "authorizationStateWaitCode":
            authState = .waitCode
            return true
        case "authorizationStateWaitPassword":
            let hint = authObj["password_hint"] as? String ?? ""
            authState = .waitPassword(hint: hint)
            return true
        case "authorizationStateReady":
            authState = .ready
            return true
        default:
            return false
        }
    }

    private func request(_ payload: [String: Any], maxIterations: Int = 40, stepTimeout: Double = 0.25) throws -> [String: Any]? {
        var req = payload
        let reqId = UUID().uuidString
        req["@extra"] = reqId
        try client.send(req)
        let deadline = Date().addingTimeInterval(max(4.0, Double(maxIterations) * stepTimeout))
        while Date() < deadline {
            guard let msg = client.receive(timeout: stepTimeout) else { continue }
            if let cid = msg["@client_id"] as? Int32, cid != client.clientId { continue }
            if let extra = msg["@extra"] as? String, extra == reqId {
                return msg
            }
            try? handlePassiveUpdate(msg)
        }
        return nil
    }

    // MARK: - Authorization Handshake
    public func configureParameters(_ config: TDLibConfiguration) throws {
        try FileManager.default.createDirectory(at: config.databaseDirectory, withIntermediateDirectories: true)
        self.activeConfig = config
        self.authState = .connecting

        let params: [String: Any] = [
            "use_test_dc": config.useTestDc,
            "database_directory": config.databaseDirectory.path,
            "files_directory": config.databaseDirectory.appendingPathComponent("files", isDirectory: true).path,
            "use_file_database": true,
            "use_chat_info_database": true,
            "use_message_database": true,
            "use_secret_chats": true,
            "api_id": config.apiId,
            "api_hash": config.apiHash,
            "system_language_code": "en",
            "device_model": "Mac (arm64)",
            "system_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "application_version": MaterialgramUpdateService.currentVersion,
            "enable_storage_optimizer": true
        ]
        if isModernTDLib {
            var flatPayload = params
            flatPayload.removeValue(forKey: "enable_storage_optimizer")
            flatPayload["@type"] = "setTdlibParameters"
            flatPayload["database_encryption_key"] = ""
            try client.send(flatPayload)
        } else {
            try client.send([
                "@type": "setTdlibParameters",
                "parameters": params
            ])
        }
    }

    public func startHandshake(config: TDLibConfiguration, maxPollIterations: Int = 40) throws -> TDLibAuthState {
        self.activeConfig = config
        self.authState = .connecting
        try client.send(["@type": "getAuthorizationState"])
        return try pollUpdates(iterations: maxPollIterations, stepTimeout: 0.25)
    }

    /// Sends phone number with full TDLib 1.8.0 `phoneNumberAuthenticationSettings`
    /// and waits for both the `@extra` RPC result (`ok`/`error`) and the resulting auth state transition.
    public func submitPhoneNumber(_ phone: String) throws -> TDLibAuthResult {
        let cleaned = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return TDLibAuthResult(state: authState, errorMessage: "Enter your phone number with country code (for example, +15551234567).")
        }
        let payload: [String: Any] = [
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": cleaned,
            "settings": [
                "@type": "phoneNumberAuthenticationSettings",
                "allow_flash_call": false,
                "allow_missed_call": false,
                "is_current_phone_number": false,
                "has_unknown_phone_number": false,
                "allow_sms_retriever_api": false,
                "authentication_tokens": []
            ]
        ]
        return try sendAuthStep(payload, expectedPreviousState: .waitPhoneNumber)
    }

    public func submitAuthCode(_ code: String) throws -> TDLibAuthResult {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return TDLibAuthResult(state: authState, errorMessage: "Enter the verification code sent by Telegram.")
        }
        return try sendAuthStep([
            "@type": "checkAuthenticationCode",
            "code": cleaned
        ], expectedPreviousState: .waitCode)
    }

    public func submitPassword(_ password: String) throws -> TDLibAuthResult {
        guard !password.isEmpty else {
            return TDLibAuthResult(state: authState, errorMessage: "Enter your Telegram two-step verification password.")
        }
        return try sendAuthStep([
            "@type": "checkAuthenticationPassword",
            "password": password
        ], expectedPreviousState: authState)
    }

    private func sendAuthStep(_ payload: [String: Any], expectedPreviousState: TDLibAuthState) throws -> TDLibAuthResult {
        var req = payload
        let reqId = UUID().uuidString
        req["@extra"] = reqId
        try client.send(req)

        var sawOk = false
        // Wait up to 20 seconds for network MTProto DC negotiation / PHONE_MIGRATE
        let deadline = Date().addingTimeInterval(20.0)
        while Date() < deadline {
            guard let msg = client.receive(timeout: 0.25) else {
                if sawOk && authState != expectedPreviousState {
                    return TDLibAuthResult(state: authState)
                }
                continue
            }
            if let cid = msg["@client_id"] as? Int32, cid != client.clientId { continue }
            let type = msg["@type"] as? String ?? ""

            if let extra = msg["@extra"] as? String, extra == reqId {
                if type == "error" {
                    let message = msg["message"] as? String ?? "Telegram rejected this request."
                    return TDLibAuthResult(state: authState, errorMessage: message)
                }
                if type == "ok" {
                    sawOk = true
                    if authState != expectedPreviousState {
                        return TDLibAuthResult(state: authState)
                    }
                    // Explicitly ask TDLib for the updated auth state after ok
                    try? client.send(["@type": "getAuthorizationState"])
                    continue
                }
            }

            try handlePassiveUpdate(msg)
            if sawOk && authState != expectedPreviousState {
                return TDLibAuthResult(state: authState)
            }
        }

        if authState != expectedPreviousState {
            return TDLibAuthResult(state: authState)
        }
        return TDLibAuthResult(
            state: authState,
            errorMessage: "Timed out waiting for Telegram's response. Check your network connection or proxy and try again."
        )
    }

    public func pollUpdates(iterations: Int = 20, stepTimeout: Double = 0.25) throws -> TDLibAuthState {
        let deadline = Date().addingTimeInterval(max(5.0, Double(iterations) * stepTimeout))
        while Date() < deadline {
            guard let msg = client.receive(timeout: stepTimeout) else { continue }
            if let cid = msg["@client_id"] as? Int32, cid != client.clientId { continue }
            guard let type = msg["@type"] as? String else { continue }

            if type == "error", let message = msg["message"] as? String {
                if message.contains("checkDatabaseEncryptionKey") {
                    try client.send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
                    continue
                }
                authState = .error(message)
                return authState
            }

            if type == "updateAuthorizationState",
               let authObj = msg["authorization_state"] as? [String: Any] {
                if try applyAuthStateObject(authObj) {
                    return authState
                }
            } else if type.hasPrefix("authorizationState") {
                if try applyAuthStateObject(msg) {
                    return authState
                }
            } else {
                try? handlePassiveUpdate(msg)
            }
        }
        return authState
    }

    // MARK: - Live Account & Proxies
    public func fetchMe() throws -> UserAccount? {
        guard authState == .ready else { return nil }
        guard let res = try request(["@type": "getMe"]),
              (res["@type"] as? String) == "user" else {
            return nil
        }
        let id = (res["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let first = res["first_name"] as? String ?? ""
        let last = res["last_name"] as? String ?? ""
        let fullName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        let displayName = fullName.isEmpty ? "Telegram User" : fullName
        let rawUsername: String
        if let usernames = res["usernames"] as? [String: Any] {
            if let editable = usernames["editable_username"] as? String, !editable.isEmpty {
                rawUsername = editable
            } else if let active = usernames["active_usernames"] as? [String], let firstHandle = active.first {
                rawUsername = firstHandle
            } else {
                rawUsername = ""
            }
        } else {
            rawUsername = res["username"] as? String ?? ""
        }
        let username = rawUsername.isEmpty ? "" : "@\(rawUsername)"
        let phone = res["phone_number"] as? String ?? ""
        let initials = Self.makeInitials(from: displayName)
        let profilePhoto = res["profile_photo"] as? [String: Any]
        let (avatarFileId, avatarLocalPath) = Self.extractFileInfo(profilePhoto?["small"] as? [String: Any])
        let profilePhotoId: Int64?
        if let num = profilePhoto?["id"] as? NSNumber {
            profilePhotoId = num.int64Value
        } else if let str = profilePhoto?["id"] as? String, let parsed = Int64(str) {
            profilePhotoId = parsed
        } else {
            profilePhotoId = nil
        }

        var bioText = ""
        var bDay: Int? = nil
        var bMonth: Int? = nil
        var bYear: Int? = nil
        if let uid = (res["id"] as? NSNumber)?.int64Value,
           let fullInfo = try? request(["@type": "getUserFullInfo", "user_id": uid], maxIterations: 12, stepTimeout: 0.15),
           (fullInfo["@type"] as? String) == "userFullInfo" {
            if let bioObj = fullInfo["bio"] as? [String: Any],
               let t = bioObj["text"] as? String {
                bioText = t
            } else if let t = fullInfo["bio"] as? String {
                bioText = t
            }
            if let bd = fullInfo["birthdate"] as? [String: Any] {
                bDay = bd["day"] as? Int
                bMonth = bd["month"] as? Int
                if let yr = bd["year"] as? Int, yr > 0 { bYear = yr }
            }
        }

        return UserAccount(
            id: id,
            firstName: first,
            lastName: last,
            name: displayName,
            username: username,
            phoneNumber: phone,
            bio: bioText,
            avatarInitials: initials,
            avatarHue: 0.58,
            avatarFileId: avatarFileId,
            avatarLocalPath: avatarLocalPath,
            profilePhotoId: profilePhotoId,
            birthDay: bDay,
            birthMonth: bMonth,
            birthYear: bYear,
            isActive: true
        )
    }

    // MARK: - Live My Account Editing & Settings RPCs (TDLib 1.8.70)
    public func updateProfileName(firstName: String, lastName: String) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        if let res = try request([
            "@type": "setName",
            "first_name": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "last_name": lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]), (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to update name"])
        }
    }

    public func updateProfileBio(_ bio: String) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        let trimmed = String(bio.prefix(70))
        if let res = try request([
            "@type": "setBio",
            "bio": trimmed
        ]), (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to update bio"])
        }
    }

    public func updateUsername(_ username: String) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        if let res = try request([
            "@type": "setUsername",
            "username": cleaned
        ]), (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to update username"])
        }
    }

    public func updateProfilePhoto(imageURL: URL) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        if let res = try request([
            "@type": "setProfilePhoto",
            "photo": [
                "@type": "inputChatPhotoStatic",
                "photo": [
                    "@type": "inputFileLocal",
                    "path": imageURL.path
                ]
            ],
            "is_public": true
        ], maxIterations: 30, stepTimeout: 0.25), (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to upload profile photo"])
        }
    }

    public func deleteProfilePhoto(photoId: Int64) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        _ = try request([
            "@type": "deleteProfilePhoto",
            "profile_photo_id": photoId
        ])
    }

    public func updateBirthdate(day: Int?, month: Int?, year: Int?) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        var payload: [String: Any] = ["@type": "setBirthdate"]
        if let day, let month, day > 0, month > 0 {
            payload["birthdate"] = [
                "@type": "birthdate",
                "day": day,
                "month": month,
                "year": year ?? 0
            ]
        }
        if let res = try request(payload), (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to update birthday"])
        }
    }

    public func logOutAccount() throws {
        guard authState == .ready else { return }
        _ = try request(["@type": "logOut"])
        authState = .waitPhoneNumber
    }

    public func fetchActiveSessions() throws -> [ActiveTelegramSession] {
        guard authState == .ready else { return [] }
        guard let res = try request(["@type": "getActiveSessions"]),
              let items = res["sessions"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { s -> ActiveTelegramSession? in
            let sid: Int64
            if let num = s["id"] as? NSNumber {
                sid = num.int64Value
            } else if let str = s["id"] as? String, let parsed = Int64(str) {
                sid = parsed
            } else {
                return nil
            }
            return ActiveTelegramSession(
                id: sid,
                applicationName: s["application_name"] as? String ?? "Telegram",
                applicationVersion: s["application_version"] as? String ?? "",
                deviceModel: s["device_model"] as? String ?? "Device",
                platform: s["platform"] as? String ?? "",
                systemVersion: s["system_version"] as? String ?? "",
                ipAddress: s["ip_address"] as? String ?? "",
                location: s["location"] as? String ?? "",
                isCurrent: s["is_current"] as? Bool ?? false
            )
        }
    }

    public func terminateSession(sessionId: Int64) throws {
        guard authState == .ready else { return }
        _ = try request([
            "@type": "terminateSession",
            "session_id": sessionId
        ])
    }

    public func fetchStorageStats() throws -> TDLibStorageStats {
        guard authState == .ready else { return TDLibStorageStats() }
        guard let res = try request(["@type": "getStorageStatisticsFast"]) else {
            return TDLibStorageStats()
        }
        let filesSize = (res["files_size"] as? NSNumber)?.int64Value ?? 0
        let count = res["file_count"] as? Int ?? 0
        let dbSize = (res["database_size"] as? NSNumber)?.int64Value ?? 0
        return TDLibStorageStats(filesSizeBytes: filesSize, fileCount: count, databaseSizeBytes: dbSize)
    }

    public func optimizeStorageCache() throws -> TDLibStorageStats {
        guard authState == .ready else { return TDLibStorageStats() }
        _ = try request([
            "@type": "optimizeStorage",
            "size": -1,
            "ttl": 0,
            "count": -1,
            "immunity_delay": 0,
            "file_types": [],
            "chat_ids": [],
            "exclude_chat_ids": [],
            "return_deleted_file_statistics": false,
            "chat_limit": 20
        ], maxIterations: 24, stepTimeout: 0.2)
        return try fetchStorageStats()
    }

    public func createChatFolder(
        title: String,
        includeContacts: Bool = true,
        includeNonContacts: Bool = false,
        includeGroups: Bool = true,
        includeChannels: Bool = true,
        includeBots: Bool = false
    ) throws {
        guard authState == .ready else { throw TDLibError.notAuthenticated }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let folderObj: [String: Any] = [
            "@type": "chatFolder",
            "name": [
                "@type": "chatFolderName",
                "text": ["@type": "formattedText", "text": trimmed],
                "animate_custom_emoji": true
            ],
            "pinned_chat_ids": [],
            "included_chat_ids": [],
            "excluded_chat_ids": [],
            "exclude_muted": false,
            "exclude_read": false,
            "exclude_archived": true,
            "include_contacts": includeContacts,
            "include_non_contacts": includeNonContacts,
            "include_bots": includeBots,
            "include_groups": includeGroups,
            "include_channels": includeChannels
        ]
        if let res = try request(["@type": "createChatFolder", "folder": folderObj]),
           (res["@type"] as? String) == "error" {
            throw NSError(domain: "TDLib", code: res["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: res["message"] as? String ?? "Failed to create folder"])
        }
    }

    public func deleteChatFolder(folderId: Int) throws {
        guard authState == .ready else { return }
        _ = try request([
            "@type": "deleteChatFolder",
            "chat_folder_id": folderId,
            "leave_chat_ids": []
        ])
    }

    public func fetchProxies() throws -> [ProxyConfig] {
        guard let res = try request(["@type": "getProxies"]),
              let items = res["proxies"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item -> ProxyConfig? in
            // TDLib 1.8.70 wraps server/port/type inside `addedProxy.proxy`; fall back to flat fields on older TDLib.
            let proxyObj = (item["proxy"] as? [String: Any]) ?? item
            guard let server = proxyObj["server"] as? String,
                  let port = proxyObj["port"] as? Int,
                  let typeObj = proxyObj["type"] as? [String: Any],
                  let typeName = typeObj["@type"] as? String else {
                return nil
            }
            let id = (item["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
            let isEnabled = item["is_enabled"] as? Bool ?? false
            switch typeName {
            case "proxyTypeMtproto":
                return ProxyConfig(
                    id: id,
                    type: .mtproto,
                    server: server,
                    port: port,
                    secret: typeObj["secret"] as? String,
                    isEnabled: isEnabled
                )
            case "proxyTypeSocks5":
                return ProxyConfig(
                    id: id,
                    type: .socks5,
                    server: server,
                    port: port,
                    username: typeObj["username"] as? String,
                    password: typeObj["password"] as? String,
                    isEnabled: isEnabled
                )
            case "proxyTypeHttp":
                return ProxyConfig(
                    id: id,
                    type: .http,
                    server: server,
                    port: port,
                    username: typeObj["username"] as? String,
                    password: typeObj["password"] as? String,
                    isEnabled: isEnabled
                )
            default:
                return nil
            }
        }
    }

    public func applyProxy(_ proxy: ProxyConfig, enable: Bool) throws {
        let typeObj: [String: Any]
        switch proxy.type {
        case .mtproto:
            typeObj = ["@type": "proxyTypeMtproto", "secret": proxy.secret ?? ""]
        case .socks5:
            typeObj = ["@type": "proxyTypeSocks5", "username": proxy.username ?? "", "password": proxy.password ?? ""]
        case .http:
            typeObj = ["@type": "proxyTypeHttp", "username": proxy.username ?? "", "password": proxy.password ?? "", "http_only": false]
        }
        if isModernTDLib {
            _ = try request([
                "@type": "addProxy",
                "proxy": [
                    "@type": "proxy",
                    "server": proxy.server,
                    "port": proxy.port,
                    "type": typeObj
                ],
                "enable": enable,
                "comment": ""
            ])
        } else {
            _ = try request([
                "@type": "addProxy",
                "server": proxy.server,
                "port": proxy.port,
                "enable": enable,
                "type": typeObj
            ])
        }
    }

    public func disableActiveProxy() throws {
        _ = try request(["@type": "disableProxy"])
    }

    // MARK: - TelegramServiceProtocol (100% Live TDLib)
    public func fetchFolders() async throws -> [Folder] {
        return cachedFolders
    }

    public func fetchChats(in folderId: String) async throws -> [Chat] {
        guard authState == .ready else { return [] }
        let chatList: [String: Any]
        if let filterId = Int(folderId) {
            if isModernTDLib {
                chatList = ["@type": "chatListFolder", "chat_folder_id": filterId]
            } else {
                chatList = ["@type": "chatListFilter", "chat_filter_id": filterId]
            }
        } else {
            chatList = ["@type": "chatListMain"]
        }
        _ = try? request(["@type": "loadChats", "chat_list": chatList, "limit": 60], maxIterations: 8, stepTimeout: 0.15)
        guard let res = try request(["@type": "getChats", "chat_list": chatList, "limit": 60]),
              let chatIds = res["chat_ids"] as? [NSNumber] else {
            return []
        }

        var chats: [Chat] = []
        for num in chatIds {
            let cid = num.int64Value
            guard let cObj = try request(["@type": "getChat", "chat_id": cid]),
                  (cObj["@type"] as? String) == "chat" else {
                continue
            }
            let title = cObj["title"] as? String ?? "Chat \(cid)"
            chatNameCache[cid] = title
            let unread = cObj["unread_count"] as? Int ?? 0
            let lastMsgObj = cObj["last_message"] as? [String: Any]
            let preview = Self.extractPreviewText(lastMsgObj)
            let timestamp = Self.formatTimestamp(lastMsgObj?["date"] as? Int ?? 0)
            let notif = cObj["notification_settings"] as? [String: Any]
            let isMuted = (notif?["mute_for"] as? Int ?? 0) > 0
            let typeObj = cObj["type"] as? [String: Any]
            let chatType = Self.mapChatType(typeObj)
            var isForum = (cObj["view_as_topics"] as? Bool) ?? false
            var isDirectMessagesGroup = false
            var memberCount: Int? = nil

            if (typeObj?["@type"] as? String) == "chatTypeSupergroup",
               let sgId = (typeObj?["supergroup_id"] as? NSNumber)?.int64Value,
               let sgObj = try? request(["@type": "getSupergroup", "supergroup_id": sgId], maxIterations: 8, stepTimeout: 0.1),
               (sgObj["@type"] as? String) == "supergroup" {
                if sgObj["is_forum"] as? Bool == true { isForum = true }
                if sgObj["is_direct_messages_group"] as? Bool == true { isDirectMessagesGroup = true }
                if let mc = sgObj["member_count"] as? Int, mc > 0 { memberCount = mc }
            }

            let subtitle: String
            switch chatType {
            case .channel:
                if let mc = memberCount {
                    subtitle = isDirectMessagesGroup ? "\(Self.formatCompactNumber(mc)) subscribers · Topics" : "\(Self.formatCompactNumber(mc)) subscribers"
                } else {
                    subtitle = isDirectMessagesGroup ? "Channel · Topics" : "Channel"
                }
            case .group:
                if let mc = memberCount {
                    subtitle = isForum ? "\(Self.formatCompactNumber(mc)) members · Forum" : "\(Self.formatCompactNumber(mc)) members"
                } else {
                    subtitle = isForum ? "Forum group" : "Group"
                }
            case .bot:
                subtitle = "Bot"
            case .direct:
                subtitle = isForum ? "Topics" : "Direct chat"
            }

            let photoObj = cObj["photo"] as? [String: Any]
            let (avatarFileId, avatarLocalPath) = Self.extractFileInfo(photoObj?["small"] as? [String: Any])
            let hue = Double(abs(cid % 100)) / 100.0
            chats.append(Chat(
                id: String(cid),
                title: title,
                subtitle: subtitle,
                avatarInitials: Self.makeInitials(from: title),
                avatarHue: hue,
                avatarFileId: avatarFileId,
                avatarLocalPath: avatarLocalPath,
                lastMessagePreview: preview,
                lastMessageTime: timestamp,
                unreadCount: unread,
                isPinned: false,
                isMuted: isMuted,
                isOnline: false,
                type: chatType,
                isForum: isForum,
                isDirectMessagesGroup: isDirectMessagesGroup,
                memberCount: memberCount
            ))
        }
        return chats
    }

    public func fetchMessages(for chatId: String) async throws -> [Message] {
        return try await fetchMessagesPage(for: chatId, fromMessageId: 0, targetCount: 45)
    }

    public func fetchOlderMessages(for chatId: String, beforeMessageId: Int64, targetCount: Int = 40) async throws -> [Message] {
        return try await fetchMessagesPage(for: chatId, fromMessageId: beforeMessageId, targetCount: targetCount)
    }

    // MARK: - Forum & Channel Topics (TDLib 1.8.70)
    public func fetchTopics(for chatId: String, isDirectMessagesGroup: Bool = false) async throws -> [ForumTopic] {
        guard authState == .ready, let numericId = Int64(chatId) else { return [] }

        if isDirectMessagesGroup {
            _ = try? request([
                "@type": "loadDirectMessagesChatTopics",
                "chat_id": numericId,
                "limit": 100
            ], maxIterations: 16, stepTimeout: 0.15)
            return Array((directMessageTopicsCache[numericId] ?? [:]).values)
                .sorted { $0.unreadCount > $1.unreadCount }
        }

        guard let res = try request([
            "@type": "getForumTopics",
            "chat_id": numericId,
            "query": "",
            "offset_date": 0,
            "offset_message_id": 0,
            "offset_forum_topic_id": 0,
            "limit": 100
        ], maxIterations: 20, stepTimeout: 0.2),
              let rawTopics = res["topics"] as? [[String: Any]] else {
            return []
        }

        return rawTopics.compactMap { item -> ForumTopic? in
            guard let info = item["info"] as? [String: Any],
                  let tid = (info["forum_topic_id"] as? NSNumber)?.int64Value else {
                return nil
            }
            let name = (info["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "General"
            let iconObj = info["icon"] as? [String: Any]
            let colorHex = (iconObj?["color"] as? Int) ?? 0x6FB9F0
            let isGeneral = info["is_general"] as? Bool ?? false
            let isClosed = info["is_closed"] as? Bool ?? false
            let isPinned = item["is_pinned"] as? Bool ?? false
            let unread = item["unread_count"] as? Int ?? 0
            let lastMsg = item["last_message"] as? [String: Any]
            let preview = Self.extractPreviewText(lastMsg)
            let ts = Self.formatTimestamp(lastMsg?["date"] as? Int ?? 0)
            return ForumTopic(
                id: tid,
                chatId: chatId,
                name: name,
                iconColorHex: colorHex,
                isGeneral: isGeneral,
                isPinned: isPinned,
                isClosed: isClosed,
                unreadCount: unread,
                lastMessagePreview: preview,
                lastMessageTime: ts,
                isDirectMessageTopic: false
            )
        }
    }

    public func fetchTopicMessages(
        for chatId: String,
        topicId: Int64,
        isDirectMessageTopic: Bool = false,
        fromMessageId: Int64 = 0,
        targetCount: Int = 45
    ) async throws -> [Message] {
        guard authState == .ready, let numericId = Int64(chatId) else { return [] }
        var collectedRaw: [[String: Any]] = []
        var seenIds = Set<Int64>()
        var cursor: Int64 = fromMessageId

        for _ in 0..<8 {
            guard collectedRaw.count < targetCount else { break }
            let remaining = max(20, targetCount - collectedRaw.count)
            let reqPayload: [String: Any]
            if isDirectMessageTopic {
                reqPayload = [
                    "@type": "getDirectMessagesChatTopicHistory",
                    "chat_id": numericId,
                    "topic_id": topicId,
                    "from_message_id": cursor,
                    "offset": 0,
                    "limit": min(50, remaining)
                ]
            } else {
                reqPayload = [
                    "@type": "getForumTopicHistory",
                    "chat_id": numericId,
                    "forum_topic_id": topicId,
                    "from_message_id": cursor,
                    "offset": 0,
                    "limit": min(50, remaining)
                ]
            }

            guard let res = try request(reqPayload, maxIterations: 24, stepTimeout: 0.2),
                  let items = res["messages"] as? [[String: Any]],
                  !items.isEmpty else {
                break
            }

            var oldestInBatch: Int64? = nil
            var addedAny = false
            for m in items {
                guard let mid = (m["id"] as? NSNumber)?.int64Value else { continue }
                oldestInBatch = mid
                if seenIds.insert(mid).inserted {
                    collectedRaw.append(m)
                    addedAny = true
                }
            }
            guard let nextCursor = oldestInBatch, nextCursor != cursor else { break }
            cursor = nextCursor
            if !addedAny { break }
        }

        let ordered = collectedRaw.reversed()
        var parsed: [Message] = []
        parsed.reserveCapacity(ordered.count)
        for m in ordered {
            parsed.append(parseMessage(m, chatId: chatId))
        }
        return parsed
    }

    /// TDLib's `getChatHistory` often returns only 1 locally cached message on the first call.
    /// Loop `from_message_id` backward until we collect `targetCount` messages or reach the start of history.
    private func fetchMessagesPage(for chatId: String, fromMessageId: Int64, targetCount: Int) async throws -> [Message] {
        guard authState == .ready, let numericId = Int64(chatId) else { return [] }
        var collectedRaw: [[String: Any]] = []
        var seenIds = Set<Int64>()
        var cursor: Int64 = fromMessageId

        for _ in 0..<8 {
            guard collectedRaw.count < targetCount else { break }
            let remaining = max(20, targetCount - collectedRaw.count)
            guard let res = try request([
                "@type": "getChatHistory",
                "chat_id": numericId,
                "from_message_id": cursor,
                "offset": 0,
                "limit": min(50, remaining),
                "only_local": false
            ], maxIterations: 24, stepTimeout: 0.2),
                  let items = res["messages"] as? [[String: Any]],
                  !items.isEmpty else {
                break
            }

            var oldestInBatch: Int64? = nil
            var addedAny = false
            for m in items {
                guard let mid = (m["id"] as? NSNumber)?.int64Value else { continue }
                oldestInBatch = mid
                if seenIds.insert(mid).inserted {
                    collectedRaw.append(m)
                    addedAny = true
                }
            }
            guard let nextCursor = oldestInBatch, nextCursor != cursor else { break }
            cursor = nextCursor
            if !addedAny { break }
        }

        // Chronological order (oldest -> newest)
        let ordered = collectedRaw.reversed()
        var parsed: [Message] = []
        parsed.reserveCapacity(ordered.count)
        for m in ordered {
            parsed.append(parseMessage(m, chatId: chatId))
        }
        return parsed
    }

    /// Downloads a TDLib file (photo, video, thumbnail, avatar) and returns its local file path.
    public func downloadMediaFile(fileId: Int32, priority: Int = 24, synchronous: Bool = true) async throws -> String? {
        guard authState == .ready, fileId > 0 else { return nil }
        guard let res = try request([
            "@type": "downloadFile",
            "file_id": fileId,
            "priority": priority,
            "offset": 0,
            "limit": 0,
            "synchronous": synchronous
        ], maxIterations: synchronous ? 60 : 12, stepTimeout: 0.25) else {
            return nil
        }
        let (_, path) = Self.extractFileInfo(res)
        return path
    }

    /// Pre-loads the first `bytes` (default 1.5 MB) of a video/animation in the background
    /// so playback starts quickly when opened.
    public func preloadFilePrefix(fileId: Int32, bytes: Int64 = 1_572_864) async {
        guard authState == .ready, fileId > 0 else { return }
        _ = try? client.send([
            "@type": "downloadFile",
            "file_id": fileId,
            "priority": 10,
            "offset": 0,
            "limit": bytes,
            "synchronous": false
        ])
    }

    /// Starts a non-blocking full file download (`synchronous: false`) and returns initial file progress.
    public func startFileDownload(fileId: Int32, priority: Int = 32) async throws -> TDLibFileProgress {
        guard authState == .ready, fileId > 0 else {
            return TDLibFileProgress(fileId: fileId, localPath: nil, downloadedSize: 0, expectedSize: 0, isCompleted: false, isDownloading: false)
        }
        let res = try request([
            "@type": "downloadFile",
            "file_id": fileId,
            "priority": priority,
            "offset": 0,
            "limit": 0,
            "synchronous": false
        ], maxIterations: 10, stepTimeout: 0.1)
        return Self.parseFileProgress(res, fallbackId: fileId)
    }

    /// Polls live TDLib `getFile` progress without blocking.
    public func queryFileProgress(fileId: Int32) async throws -> TDLibFileProgress {
        guard authState == .ready, fileId > 0 else {
            return TDLibFileProgress(fileId: fileId, localPath: nil, downloadedSize: 0, expectedSize: 0, isCompleted: false, isDownloading: false)
        }
        let res = try request([
            "@type": "getFile",
            "file_id": fileId
        ], maxIterations: 8, stepTimeout: 0.1)
        return Self.parseFileProgress(res, fallbackId: fileId)
    }

    public func cancelFileDownload(fileId: Int32) async {
        guard authState == .ready, fileId > 0 else { return }
        _ = try? client.send([
            "@type": "cancelDownloadFile",
            "file_id": fileId,
            "only_if_pending": false
        ])
    }

    /// Fetches up to `limit` messages (max 10,000) across chat, forum topic, or direct-messages topic history for export.
    public func fetchMessagesForExport(
        chatId: String,
        topicId: Int64? = nil,
        isDirectMessageTopic: Bool = false,
        limit: Int = 10_000
    ) async throws -> [Message] {
        guard authState == .ready, let numericId = Int64(chatId) else { return [] }
        let boundedLimit = min(ChatExportService.maxMessagesPerDocument, max(1, limit))
        var collectedRaw: [[String: Any]] = []
        var seenIds = Set<Int64>()
        var cursor: Int64 = 0

        let maxRounds = max(12, (boundedLimit / 40) + 8)
        for _ in 0..<maxRounds {
            guard collectedRaw.count < boundedLimit else { break }
            let batchLimit = min(100, boundedLimit - collectedRaw.count)
            let payload: [String: Any]
            if let topicId {
                if isDirectMessageTopic {
                    payload = [
                        "@type": "getDirectMessagesChatTopicHistory",
                        "chat_id": numericId,
                        "topic_id": topicId,
                        "from_message_id": cursor,
                        "offset": 0,
                        "limit": batchLimit
                    ]
                } else {
                    payload = [
                        "@type": "getForumTopicHistory",
                        "chat_id": numericId,
                        "forum_topic_id": topicId,
                        "from_message_id": cursor,
                        "offset": 0,
                        "limit": batchLimit
                    ]
                }
            } else {
                payload = [
                    "@type": "getChatHistory",
                    "chat_id": numericId,
                    "from_message_id": cursor,
                    "offset": 0,
                    "limit": batchLimit,
                    "only_local": false
                ]
            }

            guard let res = try request(payload, maxIterations: 24, stepTimeout: 0.2),
                  let items = res["messages"] as? [[String: Any]],
                  !items.isEmpty else {
                break
            }

            var oldestInBatch: Int64? = nil
            var addedAny = false
            for m in items {
                guard let mid = (m["id"] as? NSNumber)?.int64Value else { continue }
                oldestInBatch = mid
                if seenIds.insert(mid).inserted {
                    collectedRaw.append(m)
                    addedAny = true
                }
            }
            guard let nextCursor = oldestInBatch, nextCursor != cursor, addedAny else { break }
            cursor = nextCursor
        }

        let ordered = collectedRaw.reversed()
        var parsed: [Message] = []
        parsed.reserveCapacity(ordered.count)
        for m in ordered {
            parsed.append(parseMessage(m, chatId: chatId))
        }
        return parsed
    }

    private static func parseFileProgress(_ fileObj: [String: Any]?, fallbackId: Int32) -> TDLibFileProgress {
        guard let fileObj else {
            return TDLibFileProgress(fileId: fallbackId, localPath: nil, downloadedSize: 0, expectedSize: 0, isCompleted: false, isDownloading: false)
        }
        let fid = (fileObj["id"] as? NSNumber)?.int32Value ?? fallbackId
        let size = (fileObj["size"] as? NSNumber)?.int64Value ?? 0
        let expected = (fileObj["expected_size"] as? NSNumber)?.int64Value ?? size
        let local = fileObj["local"] as? [String: Any]
        let path = (local?["path"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let downloaded = (local?["downloaded_size"] as? NSNumber)?.int64Value ?? 0
        let completed = (local?["is_downloading_completed"] as? Bool) ?? false
        let active = (local?["is_downloading_active"] as? Bool) ?? false
        return TDLibFileProgress(
            fileId: fid,
            localPath: path,
            downloadedSize: downloaded,
            expectedSize: max(expected, downloaded),
            isCompleted: completed && path != nil,
            isDownloading: active
        )
    }

    private func resolveSenderName(for m: [String: Any], isOutgoing: Bool) -> String {
        if isOutgoing { return "You" }
        if let sig = m["author_signature"] as? String, !sig.isEmpty {
            return sig
        }
        guard let sender = m["sender_id"] as? [String: Any],
              let senderType = sender["@type"] as? String else {
            return "Channel"
        }
        if senderType == "messageSenderUser", let uid = (sender["user_id"] as? NSNumber)?.int64Value {
            if let cached = userNameCache[uid] { return cached }
            if let uObj = try? request(["@type": "getUser", "user_id": uid], maxIterations: 8, stepTimeout: 0.1),
               (uObj["@type"] as? String) == "user" {
                let first = uObj["first_name"] as? String ?? ""
                let last = uObj["last_name"] as? String ?? ""
                let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                let resolved = name.isEmpty ? "User \(uid)" : name
                userNameCache[uid] = resolved
                return resolved
            }
            return "User"
        } else if senderType == "messageSenderChat", let cid = (sender["chat_id"] as? NSNumber)?.int64Value {
            if let cached = chatNameCache[cid] { return cached }
            if let cObj = try? request(["@type": "getChat", "chat_id": cid], maxIterations: 8, stepTimeout: 0.1),
               let title = cObj["title"] as? String, !title.isEmpty {
                chatNameCache[cid] = title
                return title
            }
            return "Channel"
        }
        return "Member"
    }

    private func parseMessage(_ m: [String: Any], chatId: String) -> Message {
        let mid = (m["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let isOut = m["is_outgoing"] as? Bool ?? false
        let unixDate = m["date"] as? Int ?? 0
        let ts = Self.formatTimestamp(unixDate)
        let dateGroup = Self.formatDateGroup(unixDate)
        let senderName = resolveSenderName(for: m, isOutgoing: isOut)

        let content = m["content"] as? [String: Any]
        let contentType = content?["@type"] as? String ?? ""
        let (text, media, isService) = Self.extractContent(content, contentType: contentType)

        var reactions: [Reaction] = []
        var viewsCount: Int? = nil
        if let info = m["interaction_info"] as? [String: Any] {
            if let vc = info["view_count"] as? Int, vc > 0 {
                viewsCount = vc
            }
            let rawReactions: [[String: Any]]?
            if let rContainer = info["reactions"] as? [String: Any] {
                rawReactions = rContainer["reactions"] as? [[String: Any]]
            } else {
                rawReactions = info["reactions"] as? [[String: Any]]
            }
            if let rawReactions {
                for r in rawReactions {
                    let count = r["total_count"] as? Int ?? 1
                    let chosen = r["is_chosen"] as? Bool ?? false
                    if let rType = r["type"] as? [String: Any],
                       let emoji = rType["emoji"] as? String {
                        reactions.append(Reaction(emoji: emoji, count: count, isSelectedByMe: chosen))
                    }
                }
            }
        }

        return Message(
            id: mid,
            chatId: chatId,
            senderName: senderName,
            text: text,
            timestamp: ts,
            dateGroup: dateGroup,
            isOutgoing: isOut,
            isServiceMessage: isService,
            status: .read,
            reactions: reactions,
            replyToSnippet: nil,
            media: media,
            viewsCount: viewsCount
        )
    }

    public func sendMessage(chatId: String, text: String, replyTo: String?) async throws -> Message {
        return try await sendMessageInTopic(chatId: chatId, text: text, replyTo: replyTo, topicId: nil)
    }

    public func sendMessageInTopic(chatId: String, text: String, replyTo: String?, topicId: Int64?) async throws -> Message {
        guard authState == .ready, let numericId = Int64(chatId) else {
            throw TDLibError.notAuthenticated
        }
        var payload: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": numericId,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": ["@type": "formattedText", "text": text]
            ]
        ]
        if let topicId {
            payload["topic_id"] = ["@type": "messageTopicForum", "forum_topic_id": topicId]
        }
        if let replyTo, let replyId = Int64(replyTo) {
            payload["reply_to"] = ["@type": "inputMessageReplyToMessage", "message_id": replyId]
        }
        let res = try request(payload)
        let mid = (res?["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let ts = Self.formatTimestamp(Int(Date().timeIntervalSince1970))
        return Message(
            id: mid,
            chatId: chatId,
            senderName: "You",
            text: text,
            timestamp: ts,
            isOutgoing: true,
            status: .sent,
            reactions: [],
            replyToSnippet: nil
        )
    }

    public func sendDocument(chatId: String, fileURL: URL, caption: String = "", topicId: Int64? = nil) async throws -> Message {
        guard authState == .ready, let numericId = Int64(chatId) else {
            throw TDLibError.notAuthenticated
        }
        var payload: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": numericId,
            "input_message_content": [
                "@type": "inputMessageDocument",
                "document": [
                    "@type": "inputFileLocal",
                    "path": fileURL.path
                ],
                "caption": ["@type": "formattedText", "text": caption]
            ]
        ]
        if let topicId {
            payload["topic_id"] = ["@type": "messageTopicForum", "forum_topic_id": topicId]
        }
        let res = try request(payload)
        let mid = (res?["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let ts = Self.formatTimestamp(Int(Date().timeIntervalSince1970))
        let fileSize = ((try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? NSNumber)?.int64Value ?? 0
        let media = MessageMedia(kind: .document, localPath: fileURL.path, fileName: fileURL.lastPathComponent, fileSize: fileSize)
        return Message(
            id: mid,
            chatId: chatId,
            senderName: "You",
            text: caption,
            timestamp: ts,
            isOutgoing: true,
            status: .sent,
            reactions: [],
            replyToSnippet: nil,
            media: media
        )
    }

    public func sendPhoto(chatId: String, imageURL: URL, caption: String = "", topicId: Int64? = nil) async throws -> Message {
        guard authState == .ready, let numericId = Int64(chatId) else {
            throw TDLibError.notAuthenticated
        }
        var payload: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": numericId,
            "input_message_content": [
                "@type": "inputMessagePhoto",
                "photo": ["@type": "inputFileLocal", "path": imageURL.path],
                "caption": ["@type": "formattedText", "text": caption]
            ]
        ]
        if let topicId {
            payload["topic_id"] = ["@type": "messageTopicForum", "forum_topic_id": topicId]
        }
        let res = try request(payload)
        let mid = (res?["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let ts = Self.formatTimestamp(Int(Date().timeIntervalSince1970))
        let media = MessageMedia(kind: .photo, localPath: imageURL.path)
        return Message(id: mid, chatId: chatId, senderName: "You", text: caption, timestamp: ts, isOutgoing: true, status: .sent, media: media)
    }

    /// Forwards a bookmarked message, photo, or video to Telegram's cloud "Saved Messages" chat
    /// (matching iMe Messenger's Cloud Albums / Saved Messages bookmark sync).
    public func forwardMessageToSavedMessages(myUserId: Int64, fromChatId: String, messageId: String) async throws {
        guard authState == .ready,
              let numericFromChatId = Int64(fromChatId),
              let numericMsgId = Int64(messageId) else {
            throw TDLibError.notAuthenticated
        }
        guard let privateChatRes = try request([
            "@type": "createPrivateChat",
            "user_id": myUserId,
            "force": false
        ]), let savedChatId = (privateChatRes["id"] as? NSNumber)?.int64Value else {
            return
        }
        _ = try request([
            "@type": "forwardMessages",
            "chat_id": savedChatId,
            "from_chat_id": numericFromChatId,
            "message_ids": [numericMsgId],
            "send_copy": false,
            "remove_caption": false
        ])
    }

    public func sendVoiceNote(chatId: String, audioURL: URL, durationSeconds: Int, topicId: Int64? = nil) async throws -> Message {
        guard authState == .ready, let numericId = Int64(chatId) else {
            throw TDLibError.notAuthenticated
        }
        var payload: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": numericId,
            "input_message_content": [
                "@type": "inputMessageVoiceNote",
                "voice_note": ["@type": "inputFileLocal", "path": audioURL.path],
                "duration": durationSeconds
            ]
        ]
        if let topicId {
            payload["topic_id"] = ["@type": "messageTopicForum", "forum_topic_id": topicId]
        }
        let res = try request(payload)
        let mid = (res?["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
        let ts = Self.formatTimestamp(Int(Date().timeIntervalSince1970))
        let media = MessageMedia(kind: .voiceNote, localPath: audioURL.path, duration: durationSeconds)
        return Message(id: mid, chatId: chatId, senderName: "You", text: "", timestamp: ts, isOutgoing: true, status: .sent, media: media)
    }

    public func preloadFile(fileId: Int32, priority: Int = 4) async throws {
        guard authState == .ready else { return }
        try client.send([
            "@type": "downloadFile",
            "file_id": fileId,
            "priority": priority,
            "offset": 0,
            "limit": 0,
            "synchronous": false
        ])
    }

    public func fetchInstalledStickerSets() async throws -> [StickerSetSummary] {
        guard authState == .ready else { return [] }
        let stickerReq: [String: Any] = isModernTDLib
            ? ["@type": "getInstalledStickerSets", "sticker_type": ["@type": "stickerTypeRegular"]]
            : ["@type": "getInstalledStickerSets", "is_masks": false]
        guard let res = try request(stickerReq),
              let sets = res["sets"] as? [[String: Any]] else {
            return []
        }
        return sets.compactMap { s -> StickerSetSummary? in
            guard let idNum = s["id"] as? NSNumber,
                  let title = s["title"] as? String else { return nil }
            let name = s["name"] as? String ?? ""
            let count = (s["size"] as? Int) ?? (s["stickers"] as? [Any])?.count ?? 0
            return StickerSetSummary(id: idNum.int64Value, title: title, name: name, stickerCount: count, isInstalled: true)
        }
    }

    public func removeStickerSet(setId: Int64) async throws {
        guard authState == .ready else { return }
        _ = try request([
            "@type": "changeStickerSet",
            "set_id": setId,
            "is_installed": false,
            "is_archived": false
        ])
    }

    public func fetchChatEventLog(chatId: String, limit: Int = 25) async throws -> [ChatEventLogItem] {
        guard authState == .ready, let numericId = Int64(chatId) else { return [] }
        guard let res = try request([
            "@type": "getChatEventLog",
            "chat_id": numericId,
            "query": "",
            "from_event_id": 0,
            "limit": limit
        ]), let events = res["events"] as? [[String: Any]] else {
            return []
        }
        return events.map { ev in
            let id = (ev["id"] as? NSNumber)?.stringValue ?? UUID().uuidString
            let date = Self.formatTimestamp(ev["date"] as? Int ?? 0)
            let action = (ev["action"] as? [String: Any])?["@type"] as? String ?? "chatEvent"
            return ChatEventLogItem(id: id, date: date, summary: action.replacingOccurrences(of: "chatEvent", with: ""))
        }
    }

    // MARK: - Phase 5 (Option A): TDLib Call Signaling
    public func createCall(userId: Int64, isVideo: Bool = false) async throws -> Int32? {
        guard authState == .ready else { return nil }
        let res = try request([
            "@type": "createCall",
            "user_id": userId,
            "protocol": [
                "@type": "callProtocol",
                "udp_p2p": true,
                "udp_reflector": true,
                "min_layer": 65,
                "max_layer": 92,
                "library_versions": ["4.0.0"]
            ],
            "is_video": isVideo
        ])
        return (res?["id"] as? NSNumber)?.int32Value
    }

    public func acceptCall(callId: Int32) async throws {
        guard authState == .ready else { return }
        _ = try request([
            "@type": "acceptCall",
            "call_id": callId,
            "protocol": [
                "@type": "callProtocol",
                "udp_p2p": true,
                "udp_reflector": true,
                "min_layer": 65,
                "max_layer": 92,
                "library_versions": ["4.0.0"]
            ]
        ])
    }

    public func discardCall(callId: Int32) async throws {
        guard authState == .ready else { return }
        _ = try request([
            "@type": "discardCall",
            "call_id": callId,
            "is_disconnected": false,
            "invite_link": "",
            "duration": 0,
            "is_video": false,
            "connection_id": 0
        ])
    }

    public func toggleReaction(messageId: String, emoji: String, in chatId: String) async throws -> [Reaction] {
        guard authState == .ready,
              let numericChatId = Int64(chatId),
              let numericMsgId = Int64(messageId) else {
            return []
        }
        if isModernTDLib {
            _ = try request([
                "@type": "addMessageReaction",
                "chat_id": numericChatId,
                "message_id": numericMsgId,
                "reaction_type": ["@type": "reactionTypeEmoji", "emoji": emoji],
                "is_big": false,
                "update_recent_reactions": true
            ])
        } else {
            _ = try request([
                "@type": "setMessageReaction",
                "chat_id": numericChatId,
                "message_id": numericMsgId,
                "reaction": emoji,
                "is_big": false
            ])
        }
        return [Reaction(emoji: emoji, count: 1, isSelectedByMe: true)]
    }

    /// Deletes arbitrary numbers of messages in batches of 100,
    /// matching Materialgram's "Ability to delete more than 100 messages at once".
    public func deleteMessages(chatId: String, messageIds: [String], revoke: Bool = true) async throws {
        guard authState == .ready, let numericChatId = Int64(chatId) else { return }
        let numericIds = messageIds.compactMap { Int64($0) }
        guard !numericIds.isEmpty else { return }
        let batchSize = 100
        var offset = 0
        while offset < numericIds.count {
            let end = min(offset + batchSize, numericIds.count)
            let chunk = Array(numericIds[offset..<end])
            _ = try request([
                "@type": "deleteMessages",
                "chat_id": numericChatId,
                "message_ids": chunk,
                "revoke": revoke
            ])
            offset = end
        }
    }

    public func markAsRead(chatId: String) async throws {
        guard authState == .ready, let numericId = Int64(chatId) else { return }
        guard let res = try request([
            "@type": "getChatHistory",
            "chat_id": numericId,
            "from_message_id": 0,
            "offset": 0,
            "limit": 5,
            "only_local": true
        ], maxIterations: 8, stepTimeout: 0.1),
              let items = res["messages"] as? [[String: Any]] else {
            return
        }
        let ids = items.compactMap { ($0["id"] as? NSNumber)?.int64Value }
        guard !ids.isEmpty else { return }
        _ = try request([
            "@type": "viewMessages",
            "chat_id": numericId,
            "message_ids": ids,
            "force_read": true
        ], maxIterations: 6, stepTimeout: 0.1)
    }

    // MARK: - Media & Formatting Helpers
    private static func extractFileInfo(_ fileObj: [String: Any]?) -> (Int32?, String?) {
        guard let fileObj else { return (nil, nil) }
        let fileId = (fileObj["id"] as? NSNumber)?.int32Value
        if let local = fileObj["local"] as? [String: Any],
           let path = local["path"] as? String,
           !path.isEmpty,
           (local["is_downloading_completed"] as? Bool == true || FileManager.default.fileExists(atPath: path)) {
            return (fileId, path)
        }
        return (fileId, nil)
    }

    private static func extractContent(_ content: [String: Any]?, contentType: String) -> (String, MessageMedia?, Bool) {
        guard let content else { return ("", nil, false) }
        let caption = (content["caption"] as? [String: Any])?["text"] as? String ?? ""

        switch contentType {
        case "messageText":
            let text = (content["text"] as? [String: Any])?["text"] as? String ?? ""
            return (text, nil, false)

        case "messagePhoto":
            let photo = content["photo"] as? [String: Any]
            let mini = (photo?["minithumbnail"] as? [String: Any])?["data"] as? String
            let sizes = photo?["sizes"] as? [[String: Any]] ?? []
            // Prefer medium-large photo size ("x" / "y" / last) for crisp inline display
            let chosen = sizes.last(where: { ($0["width"] as? Int ?? 0) <= 1280 }) ?? sizes.last
            let photoFile = chosen?["photo"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(photoFile)
            let w = chosen?["width"] as? Int ?? 0
            let h = chosen?["height"] as? Int ?? 0
            let size = (photoFile?["expected_size"] as? NSNumber)?.int64Value ?? (photoFile?["size"] as? NSNumber)?.int64Value ?? 0
            let media = MessageMedia(
                kind: .photo,
                fileId: fileId,
                localPath: localPath,
                minithumbnailBase64: mini,
                width: w,
                height: h,
                fileSize: size
            )
            return (caption, media, false)

        case "messageVideo":
            let video = content["video"] as? [String: Any]
            let mini = (video?["minithumbnail"] as? [String: Any])?["data"] as? String
            let videoFile = video?["video"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(videoFile)
            let thumbObj = video?["thumbnail"] as? [String: Any]
            let (thumbId, thumbPath) = extractFileInfo(thumbObj?["file"] as? [String: Any])
            let duration = video?["duration"] as? Int ?? 0
            let w = video?["width"] as? Int ?? 0
            let h = video?["height"] as? Int ?? 0
            let size = (videoFile?["expected_size"] as? NSNumber)?.int64Value ?? (videoFile?["size"] as? NSNumber)?.int64Value ?? 0
            let media = MessageMedia(
                kind: .video,
                fileId: fileId,
                localPath: localPath,
                thumbnailFileId: thumbId,
                thumbnailLocalPath: thumbPath,
                minithumbnailBase64: mini,
                width: w,
                height: h,
                duration: duration,
                fileName: video?["file_name"] as? String,
                fileSize: size
            )
            return (caption, media, false)

        case "messageAnimation":
            let anim = content["animation"] as? [String: Any]
            let mini = (anim?["minithumbnail"] as? [String: Any])?["data"] as? String
            let animFile = anim?["animation"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(animFile)
            let thumbObj = anim?["thumbnail"] as? [String: Any]
            let (thumbId, thumbPath) = extractFileInfo(thumbObj?["file"] as? [String: Any])
            let duration = anim?["duration"] as? Int ?? 0
            let w = anim?["width"] as? Int ?? 0
            let h = anim?["height"] as? Int ?? 0
            let size = (animFile?["expected_size"] as? NSNumber)?.int64Value ?? (animFile?["size"] as? NSNumber)?.int64Value ?? 0
            let media = MessageMedia(
                kind: .animation,
                fileId: fileId,
                localPath: localPath,
                thumbnailFileId: thumbId,
                thumbnailLocalPath: thumbPath,
                minithumbnailBase64: mini,
                width: w,
                height: h,
                duration: duration,
                fileName: anim?["file_name"] as? String,
                fileSize: size
            )
            return (caption, media, false)

        case "messageVideoNote":
            let vn = content["video_note"] as? [String: Any]
            let mini = (vn?["minithumbnail"] as? [String: Any])?["data"] as? String
            let vnFile = vn?["video"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(vnFile)
            let thumbObj = vn?["thumbnail"] as? [String: Any]
            let (thumbId, thumbPath) = extractFileInfo(thumbObj?["file"] as? [String: Any])
            let duration = vn?["duration"] as? Int ?? 0
            let length = vn?["length"] as? Int ?? 240
            let size = (vnFile?["expected_size"] as? NSNumber)?.int64Value ?? (vnFile?["size"] as? NSNumber)?.int64Value ?? 0
            let media = MessageMedia(
                kind: .videoNote,
                fileId: fileId,
                localPath: localPath,
                thumbnailFileId: thumbId,
                thumbnailLocalPath: thumbPath,
                minithumbnailBase64: mini,
                width: length,
                height: length,
                duration: duration,
                fileSize: size
            )
            return ("", media, false)

        case "messageSticker":
            let st = content["sticker"] as? [String: Any]
            let emoji = st?["emoji"] as? String ?? ""
            let (fileId, localPath) = extractFileInfo(st?["sticker"] as? [String: Any])
            let thumbObj = st?["thumbnail"] as? [String: Any]
            let (thumbId, thumbPath) = extractFileInfo(thumbObj?["file"] as? [String: Any])
            let media = MessageMedia(
                kind: .sticker,
                fileId: fileId,
                localPath: localPath,
                thumbnailFileId: thumbId,
                thumbnailLocalPath: thumbPath,
                width: st?["width"] as? Int ?? 160,
                height: st?["height"] as? Int ?? 160
            )
            return (emoji, media, false)

        case "messageVoiceNote":
            let voice = content["voice_note"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(voice?["voice"] as? [String: Any])
            let duration = voice?["duration"] as? Int ?? 0
            let media = MessageMedia(
                kind: .voiceNote,
                fileId: fileId,
                localPath: localPath,
                duration: duration
            )
            return (caption, media, false)

        case "messageDocument":
            let doc = content["document"] as? [String: Any]
            let (fileId, localPath) = extractFileInfo(doc?["document"] as? [String: Any])
            let thumbObj = doc?["thumbnail"] as? [String: Any]
            let (thumbId, thumbPath) = extractFileInfo(thumbObj?["file"] as? [String: Any])
            let size = ((doc?["document"] as? [String: Any])?["size"] as? NSNumber)?.int64Value ?? 0
            let media = MessageMedia(
                kind: .document,
                fileId: fileId,
                localPath: localPath,
                thumbnailFileId: thumbId,
                thumbnailLocalPath: thumbPath,
                fileName: doc?["file_name"] as? String ?? "Document",
                fileSize: size
            )
            return (caption, media, false)

        case "messagePinMessage":
            return ("Pinned a message", nil, true)
        case "messageChatAddMembers":
            return ("Joined the group", nil, true)
        case "messageChatJoinByLink", "messageChatJoinByRequest":
            return ("Joined via invite link", nil, true)
        case "messageChatDeleteMember":
            return ("Left the group", nil, true)
        case "messageChatChangeTitle":
            let newTitle = content["title"] as? String ?? ""
            return (newTitle.isEmpty ? "Changed group title" : "Title changed to \"\(newTitle)\"", nil, true)
        case "messageChatChangePhoto":
            return ("Updated chat photo", nil, true)
        case "messageBasicGroupChatCreate", "messageSupergroupChatCreate":
            return ("Channel or group created", nil, true)
        default:
            if !caption.isEmpty { return (caption, nil, false) }
            let clean = contentType.replacingOccurrences(of: "message", with: "")
            return (clean.isEmpty ? "Message" : clean, nil, true)
        }
    }

    private static func extractPreviewText(_ msg: [String: Any]?) -> String {
        guard let content = msg?["content"] as? [String: Any],
              let contentType = content["@type"] as? String else {
            return ""
        }
        let (text, media, _) = extractContent(content, contentType: contentType)
        if let media {
            let prefix: String
            switch media.kind {
            case .photo: prefix = "Photo"
            case .video: prefix = "Video"
            case .animation: prefix = "GIF"
            case .videoNote: prefix = "Video message"
            case .sticker: prefix = "Sticker"
            case .voiceNote: prefix = "Voice message"
            case .document: prefix = media.fileName ?? "File"
            }
            return text.isEmpty ? prefix : "\(prefix) · \(text)"
        }
        return text
    }

    private static func mapChatType(_ typeObj: [String: Any]?) -> ChatType {
        switch typeObj?["@type"] as? String {
        case "chatTypeSupergroup":
            return (typeObj?["is_channel"] as? Bool == true) ? .channel : .group
        case "chatTypeBasicGroup":
            return .group
        default:
            return .direct
        }
    }

    private static func formatTimestamp(_ unix: Int) -> String {
        guard unix > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(unix)))
    }

    private static func formatDateGroup(_ unix: Int) -> String {
        guard unix > 0 else { return "Today" }
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func formatCompactNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000.0)
        }
        return "\(n)"
    }

    private static func makeInitials(from title: String) -> String {
        // Keep letters and digits only so emojis/symbols never pollute avatar circles
        let cleaned = title.unicodeScalars.map { scalar -> Character in
            (CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) || scalar == " ")
                ? Character(scalar) : " "
        }
        let words = String(cleaned).split(separator: " ").filter { !$0.isEmpty }
        if words.count >= 2 {
            let a = words[0].prefix(1)
            let b = words[1].prefix(1)
            return "\(a)\(b)".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "TG"
    }
}
