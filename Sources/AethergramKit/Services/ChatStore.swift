import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

public struct IdentifiableURL: Identifiable, Sendable {
    public var id: String { url.absoluteString }
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

@MainActor
private final class VoiceAudioDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: @MainActor () -> Void

    init(onFinish: @MainActor @escaping () -> Void) {
        self.onFinish = onFinish
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            onFinish()
        }
    }
}

public enum WallpaperPreset: String, CaseIterable, Identifiable, Sendable {
    case tonal = "Material Tonal"
    case telegramCats = "Telegram Pattern"
    case darkSpace = "Starlight Nebula"
    case mintGradient = "Northern Aurora"
    case sunsetGlow = "Sunset Horizon"
    case cleanMonochrome = "AMOLED Pitch"
    case customPhoto = "Custom Photo"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .tonal: return "Dynamic MD3 mesh"
        case .telegramCats: return "Classic vector motif"
        case .darkSpace: return "Deep cosmic indigo"
        case .mintGradient: return "Emerald & teal aurora"
        case .sunsetGlow: return "Warm twilight glow"
        case .cleanMonochrome: return "Pure OLED dark"
        case .customPhoto: return "Uploaded image file"
        }
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case myAccount = "My Account"
    case notifications = "Notifications and Sounds"
    case privacy = "Privacy and Security"
    case chatSettings = "Chat Settings"
    case chatFolders = "Chat Folders"
    case advanced = "Advanced"
    case speakersAndCamera = "Speakers and Camera"
    case batteryAndAnimations = "Battery and Animations"
    case language = "Language"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .myAccount: return "person.crop.circle.fill"
        case .notifications: return "bell.badge.fill"
        case .privacy: return "lock.shield.fill"
        case .chatSettings: return "paintpalette.fill"
        case .chatFolders: return "folder.fill"
        case .advanced: return "slider.horizontal.3"
        case .speakersAndCamera: return "speaker.wave.2.fill"
        case .batteryAndAnimations: return "bolt.batteryblock.fill"
        case .language: return "globe"
        }
    }
}

@MainActor
public final class ChatStore: ObservableObject {
    @Published public var folders: [Folder] = []
    @Published public var selectedFolderId: String = "all"
    @Published public var chats: [Chat] = []
    @Published public var selectedChatId: String? = nil
    @Published public var messages: [Message] = []
    @Published public var searchText: String = ""
    @Published public var inputText: String = ""
    @Published public var replyingToMessage: Message? = nil

    // Materialgram Customization State (Matching MaterialgramSection)
    @Published public var selectedSettingsSection: SettingsSection = .myAccount
    @Published public var interfaceScalePercent: Double = 100
    @Published public var palettePreset: MD3PalettePreset = .classic
    @Published public var bubbleCornerRadius: CGFloat = 16
    @Published public var compactMode: Bool = false
    @Published public var ghostMode: Bool = false
    @Published public var showReadReceipts: Bool = true
    @Published public var wallpaperPreset: WallpaperPreset = .telegramCats {
        didSet {
            UserDefaults.standard.set(wallpaperPreset.rawValue, forKey: "mg_wallpaper_preset")
        }
    }
    @Published public var customWallpaperPath: String? = nil {
        didSet {
            UserDefaults.standard.set(customWallpaperPath, forKey: "mg_custom_wallpaper_path")
        }
    }
    @Published public var wallpaperBlurRadius: Double = 0 {
        didSet {
            UserDefaults.standard.set(wallpaperBlurRadius, forKey: "mg_wallpaper_blur")
        }
    }
    @Published public var wallpaperDimming: Double = 0.15 {
        didSet {
            UserDefaults.standard.set(wallpaperDimming, forKey: "mg_wallpaper_dimming")
        }
    }
    @Published public var showWallpaperPattern: Bool = true {
        didSet {
            UserDefaults.standard.set(showWallpaperPattern, forKey: "mg_wallpaper_pattern")
        }
    }

    // Advanced -> materialgram (3 observed BuildMaterialgramSection toggles)
    @Published public var showRegistrationDate: Bool = true
    @Published public var showDatacenterId: Bool = true
    @Published public var showMaterialgramProfilePhotos: Bool = true

    // Notifications and Sounds
    @Published public var desktopNotifications: Bool = true
    @Published public var allowNotificationSound: Bool = true
    @Published public var notificationVolume: Double = 100
    @Published public var showNotificationName: Bool = true
    @Published public var showNotificationPreview: Bool = true
    @Published public var includeMutedInBadgeCount: Bool = false
    @Published public var respectSystemFocusMode: Bool = true

    // Chat Settings (Messages & Emoji)
    @Published public var sendWithEnter: Bool = true
    @Published public var largeEmoji: Bool = true
    @Published public var loopAnimatedStickers: Bool = true
    @Published public var showSensitiveContent: Bool = false

    // Advanced (Performance & Updates)
    @Published public var hardwareVideoDecoding: Bool = true
    @Published public var useSystemSpellChecker: Bool = true
    @Published public var updateAutomatically: Bool = true
    @Published public var installBetaVersions: Bool = false

    // Speakers and Camera (Live CoreAudio devices)
    @Published public var availableOutputDevices: [String] = AudioDeviceService.listOutputDevices()
    @Published public var availableInputDevices: [String] = AudioDeviceService.listInputDevices()
    @Published public var outputDevice: String = "System Default"
    @Published public var inputDevice: String = "System Default"
    @Published public var acceptCallsOnThisDevice: Bool = true

    // Battery and Animations
    @Published public var autoplayAnimatedStickers: Bool = true
    @Published public var autoplayAnimatedEmoji: Bool = true
    @Published public var animationsInChats: Bool = true
    @Published public var interfaceAnimations: Bool = true

    // Language & Translation
    @Published public var appLanguage: String = "English"
    @Published public var showTranslateButton: Bool = true
    @Published public var translateEntireChats: Bool = false

    // Inspector Panel & In-Chat Search / Export State
    @Published public var showInspector: Bool = false
    @Published public var showInChatSearch: Bool = false
    @Published public var inChatSearchQuery: String = ""
    @Published public var lastExportStatus: String? = nil

    // Phase 1-5 Parity Controllers & Sheet State
    @Published public var voiceRecorder = VoiceRecorderService()
    @Published public var photoEditorController = PhotoEditorController()
    @Published public var showStickerManagerSheet: Bool = false
    @Published public var installedStickerSets: [StickerSetSummary] = []
    @Published public var showGroupAdminSheet: Bool = false
    @Published public var chatEventLog: [ChatEventLogItem] = []
    @Published public var activeChatOnlineCount: Int = 0
    @Published public var accountPool = AccountSessionPool()
    @Published public var callState: CallSignalingState = .idle
    @Published public var activeMiniAppURL: URL? = nil
    @Published public var activePhotoEditURL: URL? = nil
    @Published public var isLoadingMessages: Bool = false
    @Published public var isLoadingOlderMessages: Bool = false
    @Published public var canLoadOlderMessages: Bool = false
    @Published public var activeMediaViewerItem: MediaViewerItem? = nil
    @Published public var activeMediaController: MediaViewerController? = nil
    @Published public var downloadingMediaMessageId: String? = nil
    @Published public var activeChatTopics: [ForumTopic] = []
    @Published public var selectedTopicId: Int64? = nil
    @Published public var isLoadingTopics: Bool = false
    @Published public var showExportSheet: Bool = false
    @Published public var exportController = ChatExportController()
    @Published public var playingVoiceMessageId: String? = nil

    // Live My Account Editing, Active Sessions, Folder Creation & Storage State
    @Published public var editFirstName: String = ""
    @Published public var editLastName: String = ""
    @Published public var editUsername: String = ""
    @Published public var editBio: String = ""
    @Published public var editBirthDay: String = ""
    @Published public var editBirthMonth: String = ""
    @Published public var editBirthYear: String = ""
    @Published public var isSavingProfile: Bool = false
    @Published public var profileStatusMessage: String? = nil
    @Published public var profileErrorMessage: String? = nil

    @Published public var activeSessions: [ActiveTelegramSession] = []
    @Published public var isLoadingSessions: Bool = false
    @Published public var storageStats = TDLibStorageStats()
    @Published public var isOptimizingStorage: Bool = false

    @Published public var newFolderName: String = ""
    @Published public var newFolderIncludeContacts: Bool = true
    @Published public var newFolderIncludeNonContacts: Bool = false
    @Published public var newFolderIncludeGroups: Bool = true
    @Published public var newFolderIncludeChannels: Bool = true
    @Published public var newFolderIncludeBots: Bool = false
    @Published public var folderStatusMessage: String? = nil

    // iMe-Style Bookmarks & Cloud Albums (Messages, Photos, Videos, Files)
    @Published public var bookmarks: [BookmarkItem] = []
    @Published public var showBookmarksSheet: Bool = false
    @Published public var selectedBookmarkCategory: BookmarkCategory = .all
    @Published public var bookmarkCurrentChatOnly: Bool = false
    @Published public var bookmarkSearchQuery: String = ""
    @Published public var scrollToMessageIdRequest: String? = nil
    @Published public var bookmarkStatusMessage: String? = nil

    private var voiceAudioPlayer: AVAudioPlayer?
    private var voiceAudioDelegate: VoiceAudioDelegate?

    public var selectedTopic: ForumTopic? {
        guard let tid = selectedTopicId else { return nil }
        return activeChatTopics.first { $0.id == tid }
    }

    // Multi-Account Support (Populated from live TDLib getMe)
    @Published public var accounts: [UserAccount] = []
    @Published public var activeAccountId: String = ""

    // Proxy & Connection State (Populated from live TDLib getProxies)
    @Published public var proxies: [ProxyConfig] = []
    @Published public var isProxyEnabled: Bool = false
    @Published public var showProxySheet: Bool = false
    @Published public var newProxyType: ProxyType = .mtproto
    @Published public var newProxyServer: String = ""
    @Published public var newProxyPort: String = "443"
    @Published public var newProxySecret: String = ""
    @Published public var newProxyUsername: String = ""
    @Published public var newProxyPassword: String = ""

    // Security & Passcode
    @Published public var passcodeManager = PasscodeManager()
    @Published public var newPasscodeInput: String = ""

    // Update Checker & TDLib Live Auth State
    @Published public var isCheckingForUpdates: Bool = false
    @Published public var isDownloadingUpdate: Bool = false
    @Published public var updateInfo: UpdateInfo? = nil
    @Published public var stagedUpdateFileURL: URL? = nil
    @Published public var updateStatusMessage: String? = nil
    @Published public var updateErrorMessage: String? = nil
    @Published public var showSettingsSheet: Bool = false
    @Published public var tdlibVersion: String? = nil
    @Published public var tdlibAuthState: TDLibAuthState = .unconfigured
    @Published public var isSubmittingAuth: Bool = false
    @Published public var authErrorMessage: String? = nil
    @Published public var authPhoneInput: String = ""
    @Published public var authCodeInput: String = ""
    @Published public var authPasswordInput: String = ""

    private let telegramService: (any TelegramServiceProtocol)?
    public let tdlibProvider: TDLibTelegramProvider?
    private let updateService = MaterialgramUpdateService()

    public init(telegramService: (any TelegramServiceProtocol)? = nil) {
        if let provided = telegramService {
            self.telegramService = provided
            self.tdlibProvider = provided as? TDLibTelegramProvider
            if let td = self.tdlibProvider {
                self.tdlibVersion = td.tdlibVersion
            }
        } else if let tdProvider = try? TDLibTelegramProvider() {
            self.telegramService = tdProvider
            self.tdlibProvider = tdProvider
            self.tdlibVersion = tdProvider.tdlibVersion
        } else {
            self.telegramService = nil
            self.tdlibProvider = nil
            self.tdlibAuthState = .error("Could not load TDLib. Install libtdjson.dylib and restart \(AethergramBrand.appName).")
        }

        // Restore persisted wallpaper configuration
        if let savedPath = UserDefaults.standard.string(forKey: "mg_custom_wallpaper_path"),
           FileManager.default.fileExists(atPath: savedPath) {
            self.customWallpaperPath = savedPath
        }
        if let savedPresetRaw = UserDefaults.standard.string(forKey: "mg_wallpaper_preset"),
           let savedPreset = WallpaperPreset(rawValue: savedPresetRaw) {
            if savedPreset == .customPhoto && self.customWallpaperPath == nil {
                self.wallpaperPreset = .telegramCats
            } else {
                self.wallpaperPreset = savedPreset
            }
        }
        if UserDefaults.standard.object(forKey: "mg_wallpaper_blur") != nil {
            self.wallpaperBlurRadius = UserDefaults.standard.double(forKey: "mg_wallpaper_blur")
        }
        if UserDefaults.standard.object(forKey: "mg_wallpaper_dimming") != nil {
            self.wallpaperDimming = UserDefaults.standard.double(forKey: "mg_wallpaper_dimming")
        }
        if UserDefaults.standard.object(forKey: "mg_wallpaper_pattern") != nil {
            self.showWallpaperPattern = UserDefaults.standard.bool(forKey: "mg_wallpaper_pattern")
        }
        self.bookmarks = BookmarkService.loadBookmarks()
    }

    /// Copies a user-selected image file into Application Support/Materialgram/wallpapers
    /// and activates `.customPhoto` wallpaper mode.
    @discardableResult
    public func setCustomWallpaper(from sourceURL: URL) throws -> URL {
        let wallpapersDir = TDLibConfiguration.defaultSupportDirectory()
            .appendingPathComponent("wallpapers", isDirectory: true)
        try FileManager.default.createDirectory(at: wallpapersDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let destURL = wallpapersDir.appendingPathComponent("custom_wallpaper.\(ext)")
        if sourceURL.standardizedFileURL != destURL.standardizedFileURL {
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        self.customWallpaperPath = destURL.path
        self.wallpaperPreset = .customPhoto
        return destURL
    }

    public func chooseCustomWallpaperFromFiles() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Choose Chat Wallpaper Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            _ = try? setCustomWallpaper(from: url)
        }
        #endif
    }

    public func clearCustomWallpaper() {
        if let path = customWallpaperPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        customWallpaperPath = nil
        if wallpaperPreset == .customPhoto {
            wallpaperPreset = .telegramCats
        }
    }

    public func connectTDLib() async {
        guard let tdlibProvider else {
            tdlibAuthState = .error("Could not load TDLib. Install libtdjson.dylib and restart \(AethergramBrand.appName).")
            return
        }
        guard let config = TDLibConfiguration.loadFromEnvironmentOrDisk() else {
            tdlibAuthState = .error("Telegram API credentials are missing. Add tdlib_config.json or set TELEGRAM_API_ID and TELEGRAM_API_HASH.")
            return
        }
        authErrorMessage = nil
        tdlibAuthState = .connecting
        do {
            let state = try await tdlibProvider.startHandshake(config: config)
            tdlibAuthState = state
            await syncLiveStateAfterAuth()
        } catch {
            tdlibAuthState = .error(error.localizedDescription)
        }
    }

    public func submitTDLibPhone() async {
        guard let tdlibProvider, !isSubmittingAuth else { return }
        let phone = authPhoneInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else {
            authErrorMessage = "Enter your phone number with country code (for example, +15551234567)."
            return
        }
        isSubmittingAuth = true
        authErrorMessage = nil
        defer { isSubmittingAuth = false }
        do {
            let result = try await tdlibProvider.submitPhoneNumber(phone)
            tdlibAuthState = result.state
            authErrorMessage = result.errorMessage
            await syncLiveStateAfterAuth()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func submitTDLibCode() async {
        guard let tdlibProvider, !isSubmittingAuth else { return }
        let code = authCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            authErrorMessage = "Enter the verification code sent by Telegram."
            return
        }
        isSubmittingAuth = true
        authErrorMessage = nil
        defer { isSubmittingAuth = false }
        do {
            let result = try await tdlibProvider.submitAuthCode(code)
            tdlibAuthState = result.state
            authErrorMessage = result.errorMessage
            if result.errorMessage == nil { authCodeInput = "" }
            await syncLiveStateAfterAuth()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func submitTDLibPassword() async {
        guard let tdlibProvider, !isSubmittingAuth else { return }
        guard !authPasswordInput.isEmpty else {
            authErrorMessage = "Enter your Telegram two-step verification password."
            return
        }
        isSubmittingAuth = true
        authErrorMessage = nil
        defer { isSubmittingAuth = false }
        do {
            let result = try await tdlibProvider.submitPassword(authPasswordInput)
            tdlibAuthState = result.state
            authErrorMessage = result.errorMessage
            if result.errorMessage == nil { authPasswordInput = "" }
            await syncLiveStateAfterAuth()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func addNewProxy() async {
        let server = newProxyServer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !server.isEmpty, let port = Int(newProxyPort.trimmingCharacters(in: .whitespacesAndNewlines)), port > 0, port <= 65535 else {
            return
        }
        let proxy = ProxyConfig(
            type: newProxyType,
            server: server,
            port: port,
            username: newProxyUsername.isEmpty ? nil : newProxyUsername,
            password: newProxyPassword.isEmpty ? nil : newProxyPassword,
            secret: newProxySecret.isEmpty ? nil : newProxySecret,
            isEnabled: true
        )
        newProxyServer = ""
        newProxySecret = ""
        newProxyUsername = ""
        newProxyPassword = ""
        if let tdlibProvider {
            try? await tdlibProvider.applyProxy(proxy, enable: true)
            if let liveProxies = try? await tdlibProvider.fetchProxies() {
                proxies = liveProxies
                isProxyEnabled = liveProxies.contains(where: { $0.isEnabled })
                return
            }
        }
        for idx in 0..<proxies.count { proxies[idx].isEnabled = false }
        proxies.append(proxy)
        isProxyEnabled = true
    }

    private func syncLiveStateAfterAuth() async {
        guard let tdlibProvider else { return }
        if let liveProxies = try? await tdlibProvider.fetchProxies() {
            proxies = liveProxies
            isProxyEnabled = liveProxies.contains(where: { $0.isEnabled })
        }
        guard tdlibAuthState == .ready else { return }
        if let me = try? await tdlibProvider.fetchMe() {
            accounts = [me]
            activeAccountId = me.id
            populateProfileEditFields(from: me)
        }
        if let liveFolders = try? await tdlibProvider.fetchFolders() {
            folders = liveFolders
        }
        Task {
            await self.refreshActiveSessions()
            await self.refreshStorageStats()
        }
        await selectFolder(id: selectedFolderId)
    }

    public func populateProfileEditFields(from acc: UserAccount) {
        editFirstName = acc.firstName
        editLastName = acc.lastName
        editUsername = acc.username.replacingOccurrences(of: "@", with: "")
        editBio = acc.bio
        editBirthDay = acc.birthDay.map { "\($0)" } ?? ""
        editBirthMonth = acc.birthMonth.map { "\($0)" } ?? ""
        editBirthYear = acc.birthYear.map { "\($0)" } ?? ""
    }

    public func refreshMyAccountProfile() async {
        guard let tdlibProvider, tdlibAuthState == .ready else { return }
        if let me = try? await tdlibProvider.fetchMe() {
            accounts = [me]
            activeAccountId = me.id
            populateProfileEditFields(from: me)
            Task { await self.hydrateAvatars() }
        }
    }

    public func saveProfileName() async {
        let first = editFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = editLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty else {
            profileErrorMessage = "First name cannot be empty."
            return
        }
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.updateProfileName(firstName: first, lastName: last)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].firstName = first
                accounts[idx].lastName = last
                accounts[idx].name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            }
            profileStatusMessage = "Saved display name."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func saveProfileBio() async {
        let trimmed = String(editBio.prefix(70))
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.updateProfileBio(trimmed)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].bio = trimmed
            }
            profileStatusMessage = "Saved bio (\(trimmed.count)/70)."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func saveProfileUsername() async {
        let clean = editUsername.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.updateUsername(clean)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].username = clean.isEmpty ? "" : "@\(clean)"
            }
            profileStatusMessage = clean.isEmpty ? "Removed username." : "Saved username @\(clean)."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func saveProfileBirthdate() async {
        let d = Int(editBirthDay.trimmingCharacters(in: .whitespacesAndNewlines))
        let m = Int(editBirthMonth.trimmingCharacters(in: .whitespacesAndNewlines))
        let y = Int(editBirthYear.trimmingCharacters(in: .whitespacesAndNewlines))
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.updateBirthdate(day: d, month: m, year: y)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].birthDay = d
                accounts[idx].birthMonth = m
                accounts[idx].birthYear = y
            }
            profileStatusMessage = (d != nil && m != nil) ? "Saved birthday." : "Cleared birthday."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func chooseAndUploadProfilePhoto() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Choose Profile Photo"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await uploadProfilePhoto(from: url)
            }
        }
        #endif
    }

    public func uploadProfilePhoto(from url: URL) async {
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.updateProfilePhoto(imageURL: url)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].avatarLocalPath = url.path
            }
            profileStatusMessage = "Updated profile photo."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func removeCurrentProfilePhoto() async {
        isSavingProfile = true
        profileErrorMessage = nil
        profileStatusMessage = nil
        defer { isSavingProfile = false }
        do {
            if let tdlibProvider, tdlibAuthState == .ready, let pid = activeAccount?.profilePhotoId {
                try await tdlibProvider.deleteProfilePhoto(photoId: pid)
                await refreshMyAccountProfile()
            } else if let idx = accounts.firstIndex(where: { $0.id == activeAccountId }) {
                accounts[idx].avatarLocalPath = nil
                accounts[idx].profilePhotoId = nil
            }
            profileStatusMessage = "Removed profile photo."
        } catch {
            profileErrorMessage = error.localizedDescription
        }
    }

    public func logOutCurrentAccount() async {
        if let tdlibProvider, tdlibAuthState == .ready {
            try? await tdlibProvider.logOutAccount()
            tdlibAuthState = .waitPhoneNumber
        }
        accounts = []
        activeAccountId = ""
        chats = []
        messages = []
        selectedChatId = nil
        profileStatusMessage = "Logged out."
    }

    public func refreshActiveSessions() async {
        guard let tdlibProvider, tdlibAuthState == .ready else { return }
        isLoadingSessions = true
        defer { isLoadingSessions = false }
        if let list = try? await tdlibProvider.fetchActiveSessions() {
            activeSessions = list
        }
    }

    public func terminateActiveSession(_ sessionId: Int64) async {
        guard let tdlibProvider, tdlibAuthState == .ready else { return }
        try? await tdlibProvider.terminateSession(sessionId: sessionId)
        activeSessions.removeAll { $0.id == sessionId }
    }

    public func refreshStorageStats() async {
        guard let tdlibProvider, tdlibAuthState == .ready else { return }
        if let stats = try? await tdlibProvider.fetchStorageStats() {
            storageStats = stats
        }
    }

    public func clearAndOptimizeStorage() async {
        guard let tdlibProvider, tdlibAuthState == .ready else { return }
        isOptimizingStorage = true
        defer { isOptimizingStorage = false }
        if let stats = try? await tdlibProvider.optimizeStorageCache() {
            storageStats = stats
        }
    }

    public func createNewChatFolder() async {
        let title = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            folderStatusMessage = "Enter a folder name."
            return
        }
        do {
            if let tdlibProvider, tdlibAuthState == .ready {
                try await tdlibProvider.createChatFolder(
                    title: title,
                    includeContacts: newFolderIncludeContacts,
                    includeNonContacts: newFolderIncludeNonContacts,
                    includeGroups: newFolderIncludeGroups,
                    includeChannels: newFolderIncludeChannels,
                    includeBots: newFolderIncludeBots
                )
                if let updated = try? await tdlibProvider.fetchFolders() {
                    folders = updated
                }
            } else {
                folders.append(Folder(id: UUID().uuidString, name: title, iconName: "folder.fill", badgeCount: 0))
            }
            newFolderName = ""
            folderStatusMessage = "Created folder \"\(title)\"."
        } catch {
            folderStatusMessage = error.localizedDescription
        }
    }

    public func deleteChatFolder(_ folder: Folder) async {
        guard folder.id != "all" else { return }
        if let fid = Int(folder.id), let tdlibProvider, tdlibAuthState == .ready {
            try? await tdlibProvider.deleteChatFolder(folderId: fid)
        }
        folders.removeAll { $0.id == folder.id }
        if selectedFolderId == folder.id {
            await selectFolder(id: "all")
        }
        folderStatusMessage = "Removed folder \"\(folder.name)\"."
    }

    public var activeAccount: UserAccount? {
        accounts.first(where: { $0.id == activeAccountId })
    }

    public var selectedChat: Chat? {
        chats.first(where: { $0.id == selectedChatId })
    }

    public var filteredChats: [Chat] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return chats
        }
        return chats.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.lastMessagePreview.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var filteredMessages: [Message] {
        let q = inChatSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard showInChatSearch, !q.isEmpty else { return messages }
        return messages.filter {
            $0.text.localizedCaseInsensitiveContains(q) ||
            $0.senderName.localizedCaseInsensitiveContains(q)
        }
    }

    public func exportSelectedChat() {
        guard let chat = selectedChat else {
            lastExportStatus = "Select a chat to export."
            return
        }
        do {
            let url = try ChatExportService.exportChatHTML(chat: chat, messages: messages)
            lastExportStatus = "Exported to \(url.lastPathComponent)"
        } catch {
            lastExportStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    public func runFullChatExport() async {
        guard let chat = selectedChat else {
            exportController.errorMessage = "Select a chat to export."
            return
        }
        exportController.isExporting = true
        exportController.errorMessage = nil
        exportController.lastResult = nil
        let options = exportController.makeOptions()
        exportController.statusText = "Fetching up to \(options.maxMessages) messages from Telegram..."

        defer { exportController.isExporting = false }
        do {
            let exportMessages: [Message]
            if let tdlibProvider {
                exportMessages = try await tdlibProvider.fetchMessagesForExport(
                    chatId: chat.id,
                    topicId: selectedTopicId,
                    isDirectMessageTopic: selectedTopic?.isDirectMessageTopic ?? false,
                    limit: options.maxMessages
                )
            } else {
                exportMessages = messages
            }

            exportController.statusText = "Writing \(options.format.rawValue) archive..."
            let result = try ChatExportService.exportChatBundle(
                chat: chat,
                messages: exportMessages.isEmpty ? messages : exportMessages,
                options: options
            )
            exportController.lastResult = result
            let summary = "Exported \(result.messageCount) messages & \(result.mediaFilesCopied) media files to \(result.exportFolderURL.lastPathComponent)"
            exportController.statusText = summary
            lastExportStatus = summary
        } catch {
            let msg = "Export failed: \(error.localizedDescription)"
            exportController.errorMessage = msg
            exportController.statusText = msg
            lastExportStatus = msg
        }
    }

    public func deleteMessagesBulk(ids: [String]) async {
        guard let chatId = selectedChatId, !ids.isEmpty else { return }
        if let tdlibProvider {
            try? await tdlibProvider.deleteMessages(chatId: chatId, messageIds: ids, revoke: true)
        }
        let idSet = Set(ids)
        messages.removeAll { idSet.contains($0.id) }
    }

    public func toggleVoiceRecording() async {
        if voiceRecorder.isRecording {
            if let recorded = voiceRecorder.stopRecording(), let chatId = selectedChatId, let tdlibProvider {
                if let msg = try? await tdlibProvider.sendVoiceNote(
                    chatId: chatId,
                    audioURL: recorded.url,
                    durationSeconds: recorded.durationSeconds,
                    topicId: selectedTopicId
                ) {
                    messages.append(msg)
                }
            }
        } else {
            voiceRecorder.startRecording()
        }
    }

    public func sendEditedPhoto(url: URL) async {
        activePhotoEditURL = nil
        guard let chatId = selectedChatId, let tdlibProvider else { return }
        if let msg = try? await tdlibProvider.sendPhoto(
            chatId: chatId,
            imageURL: url,
            caption: inputText,
            topicId: selectedTopicId
        ) {
            inputText = ""
            messages.append(msg)
        }
    }

    public func loadInstalledStickerSets() async {
        guard let tdlibProvider else { return }
        if let sets = try? await tdlibProvider.fetchInstalledStickerSets() {
            installedStickerSets = sets
        }
    }

    public func removeStickerSet(setId: Int64) async {
        guard let tdlibProvider else { return }
        try? await tdlibProvider.removeStickerSet(setId: setId)
        installedStickerSets.removeAll { $0.id == setId }
    }

    public func loadChatEventLog(chatId: String) async {
        guard let tdlibProvider else { return }
        if let log = try? await tdlibProvider.fetchChatEventLog(chatId: chatId) {
            chatEventLog = log
        }
    }

    public func startCallForSelectedChat() async {
        guard let chat = selectedChat, let uid = Int64(chat.id), let tdlibProvider else { return }
        if let cid = try? await tdlibProvider.createCall(userId: uid, isVideo: false) {
            callState = .outgoing(callId: cid, peerTitle: chat.title)
        }
    }

    public func acceptActiveCall(callId: Int32) async {
        if let tdlibProvider {
            try? await tdlibProvider.acceptCall(callId: callId)
        }
        if case .incoming(_, let title) = callState {
            callState = .activeSignaling(callId: callId, peerTitle: title)
        }
    }

    public func discardActiveCall(callId: Int32) async {
        if let tdlibProvider {
            try? await tdlibProvider.discardCall(callId: callId)
        }
        callState = .ended(reason: "Disconnected")
    }

    public func loadInitialData() async {
        MD3Typography.registerBundledFonts()
        availableOutputDevices = AudioDeviceService.listOutputDevices()
        availableInputDevices = AudioDeviceService.listInputDevices()

        if let telegramService {
            do {
                folders = try await telegramService.fetchFolders()
            } catch {
                print("Error loading folders: \(error)")
            }
        }

        if tdlibAuthState == .unconfigured && TDLibConfiguration.loadFromEnvironmentOrDisk() != nil {
            await connectTDLib()
        } else {
            await selectFolder(id: selectedFolderId)
        }
    }

    public func selectFolder(id: String) async {
        selectedFolderId = id
        guard let telegramService else { return }
        do {
            chats = try await telegramService.fetchChats(in: id)
            Task { await self.hydrateAvatars() }
            if selectedChatId == nil || !chats.contains(where: { $0.id == selectedChatId }) {
                if let first = chats.first {
                    await selectChat(id: first.id)
                } else {
                    selectedChatId = nil
                    messages = []
                }
            } else if let sel = selectedChatId {
                await selectChat(id: sel)
            }
        } catch {
            print("Error fetching chats: \(error)")
        }
    }

    public func selectChat(id: String) async {
        selectedChatId = id
        selectedTopicId = nil
        activeChatTopics = []
        guard let telegramService else { return }
        isLoadingMessages = true
        defer { isLoadingMessages = false }

        if let chat = chats.first(where: { $0.id == id }),
           (chat.isForum || chat.isDirectMessagesGroup),
           let tdlibProvider {
            isLoadingTopics = true
            let loadedTopics = (try? await tdlibProvider.fetchTopics(for: id, isDirectMessagesGroup: chat.isDirectMessagesGroup)) ?? []
            if selectedChatId == id {
                activeChatTopics = loadedTopics
            }
            isLoadingTopics = false
        }

        do {
            let fetched = try await telegramService.fetchMessages(for: id)
            guard selectedChatId == id else { return }
            messages = fetched
            canLoadOlderMessages = fetched.count >= 5
            Task { await self.hydrateVisibleMedia(for: id) }
            if showReadReceipts {
                try? await telegramService.markAsRead(chatId: id)
                if let idx = chats.firstIndex(where: { $0.id == id }) {
                    chats[idx] = Chat(
                        id: chats[idx].id,
                        title: chats[idx].title,
                        subtitle: chats[idx].subtitle,
                        avatarInitials: chats[idx].avatarInitials,
                        avatarHue: chats[idx].avatarHue,
                        avatarFileId: chats[idx].avatarFileId,
                        avatarLocalPath: chats[idx].avatarLocalPath,
                        lastMessagePreview: chats[idx].lastMessagePreview,
                        lastMessageTime: chats[idx].lastMessageTime,
                        unreadCount: 0,
                        isPinned: chats[idx].isPinned,
                        isMuted: chats[idx].isMuted,
                        isOnline: chats[idx].isOnline,
                        type: chats[idx].type,
                        isForum: chats[idx].isForum,
                        isDirectMessagesGroup: chats[idx].isDirectMessagesGroup,
                        memberCount: chats[idx].memberCount,
                        username: chats[idx].username,
                        datacenterId: chats[idx].datacenterId
                    )
                }
            }
        } catch {
            print("Error fetching messages: \(error)")
        }
    }

    public func selectTopic(_ topic: ForumTopic?) async {
        guard let chatId = selectedChatId else { return }
        selectedTopicId = topic?.id
        isLoadingMessages = true
        defer { isLoadingMessages = false }
        do {
            let fetched: [Message]
            if let topic, let tdlibProvider {
                fetched = try await tdlibProvider.fetchTopicMessages(
                    for: chatId,
                    topicId: topic.id,
                    isDirectMessageTopic: topic.isDirectMessageTopic,
                    fromMessageId: 0,
                    targetCount: 45
                )
            } else if let telegramService {
                fetched = try await telegramService.fetchMessages(for: chatId)
            } else {
                fetched = []
            }
            guard selectedChatId == chatId, selectedTopicId == topic?.id else { return }
            messages = fetched
            canLoadOlderMessages = fetched.count >= 5
            Task { await self.hydrateVisibleMedia(for: chatId) }
        } catch {
            print("Error fetching topic messages: \(error)")
        }
    }

    public func loadOlderMessages() async {
        guard let chatId = selectedChatId,
              let tdlibProvider,
              let oldest = messages.first,
              let oldestId = Int64(oldest.id),
              !isLoadingOlderMessages else { return }
        isLoadingOlderMessages = true
        defer { isLoadingOlderMessages = false }
        do {
            let older: [Message]
            if let topic = selectedTopic {
                older = try await tdlibProvider.fetchTopicMessages(
                    for: chatId,
                    topicId: topic.id,
                    isDirectMessageTopic: topic.isDirectMessageTopic,
                    fromMessageId: oldestId,
                    targetCount: 40
                )
            } else {
                older = try await tdlibProvider.fetchOlderMessages(for: chatId, beforeMessageId: oldestId, targetCount: 40)
            }
            guard selectedChatId == chatId else { return }
            let existingIds = Set(messages.map(\.id))
            let uniqueOlder = older.filter { !existingIds.contains($0.id) }
            if uniqueOlder.isEmpty {
                canLoadOlderMessages = false
            } else {
                messages.insert(contentsOf: uniqueOlder, at: 0)
                Task { await self.hydrateVisibleMedia(for: chatId) }
            }
        } catch {
            print("Error loading older messages: \(error)")
        }
    }

    public func openMediaViewer(for message: Message) async {
        guard let media = message.media else { return }
        let isVideo = (media.kind == .video || media.kind == .animation || media.kind == .videoNote)
        let isRound = (media.kind == .videoNote)
        let isAnimation = (media.kind == .animation)
        let existingURL = media.localPath.flatMap { path -> URL? in
            FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }

        let item = MediaViewerItem(
            id: message.id,
            title: media.fileName ?? message.senderName,
            fileId: media.fileId,
            localFileURL: existingURL,
            thumbnailPath: media.thumbnailLocalPath,
            minithumbnailBase64: media.minithumbnailBase64,
            isVideo: isVideo,
            isRoundVideo: isRound,
            isAnimation: isAnimation,
            expectedFileSize: media.fileSize,
            datacenterId: selectedChat?.datacenterId,
            originalDate: "\(message.dateGroup) \(message.timestamp)",
            platformName: "macOS · TDLib \(tdlibVersion ?? "1.8.70")"
        )
        activeMediaController = MediaViewerController(item: item)
        activeMediaViewerItem = item
    }

    public func updateMessageMediaLocalPath(messageId: String, path: String) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].media?.localPath = path
        }
        if let bIdx = bookmarks.firstIndex(where: { $0.messageId == messageId }) {
            bookmarks[bIdx].mediaLocalPath = path
            try? BookmarkService.saveBookmarks(bookmarks)
        }
    }

    // MARK: - iMe-Style Bookmarks & Cloud Albums (Messages, Photos, Videos)
    public var filteredBookmarks: [BookmarkItem] {
        let chatFilter = bookmarkCurrentChatOnly ? selectedChatId : nil
        return BookmarkService.filter(
            bookmarks,
            category: selectedBookmarkCategory,
            chatId: chatFilter,
            searchQuery: bookmarkSearchQuery
        )
    }

    public func bookmarkCount(for category: BookmarkCategory) -> Int {
        let chatFilter = bookmarkCurrentChatOnly ? selectedChatId : nil
        return BookmarkService.filter(
            bookmarks,
            category: category,
            chatId: chatFilter,
            searchQuery: ""
        ).count
    }

    public func isMessageBookmarked(_ messageId: String, chatId: String? = nil) -> Bool {
        let cid = chatId ?? selectedChatId ?? ""
        let key = "\(cid)_\(messageId)"
        return bookmarks.contains { $0.id == key || $0.messageId == messageId }
    }

    public func toggleBookmark(
        for message: Message,
        albumTag: String = "Saved",
        syncToTelegramCloud: Bool = false
    ) {
        let cid = message.chatId.isEmpty ? (selectedChatId ?? "") : message.chatId
        let key = "\(cid)_\(message.id)"

        if let existingIdx = bookmarks.firstIndex(where: { $0.id == key || $0.messageId == message.id }) {
            bookmarks.remove(at: existingIdx)
            try? BookmarkService.saveBookmarks(bookmarks)
            bookmarkStatusMessage = "Removed from Bookmarks."
            return
        }

        let chatTitle = chats.first(where: { $0.id == cid })?.title ?? selectedChat?.title ?? "Chat"
        let item = BookmarkItem(
            message: message,
            chatTitle: chatTitle,
            topicId: selectedTopicId,
            topicName: selectedTopic?.name,
            albumTag: albumTag
        )
        bookmarks.insert(item, at: 0)
        try? BookmarkService.saveBookmarks(bookmarks)
        bookmarkStatusMessage = "Added \(item.category.rawValue.lowercased()) bookmark."

        if syncToTelegramCloud {
            Task {
                await forwardBookmarkToTelegramCloud(item)
            }
        }
    }

    public func removeBookmark(_ item: BookmarkItem) {
        bookmarks.removeAll { $0.id == item.id }
        try? BookmarkService.saveBookmarks(bookmarks)
    }

    public func forwardBookmarkToTelegramCloud(_ item: BookmarkItem) async {
        guard let tdlibProvider,
              tdlibAuthState == .ready,
              let myIdStr = activeAccount?.id,
              let myUserId = Int64(myIdStr) else {
            return
        }
        do {
            try await tdlibProvider.forwardMessageToSavedMessages(
                myUserId: myUserId,
                fromChatId: item.chatId,
                messageId: item.messageId
            )
            bookmarkStatusMessage = "Synced bookmark to Telegram Cloud (Saved Messages)."
        } catch {
            bookmarkStatusMessage = "Failed to sync to Telegram Cloud: \(error.localizedDescription)"
        }
    }

    public func jumpToBookmark(_ item: BookmarkItem) async {
        showBookmarksSheet = false
        if selectedChatId != item.chatId {
            await selectChat(id: item.chatId)
        }
        if let tid = item.topicId,
           selectedTopicId != tid,
           let topic = activeChatTopics.first(where: { $0.id == tid }) {
            await selectTopic(topic)
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        scrollToMessageIdRequest = item.messageId
    }

    public func openBookmarkedMedia(_ item: BookmarkItem) async {
        let msg = item.reconstructedMessage
        guard msg.media != nil else {
            await jumpToBookmark(item)
            return
        }
        showBookmarksSheet = false
        try? await Task.sleep(nanoseconds: 140_000_000)
        await openMediaViewer(for: msg)
    }

    public func toggleVoiceNotePlayback(for message: Message) async {
        if playingVoiceMessageId == message.id {
            voiceAudioPlayer?.stop()
            voiceAudioPlayer = nil
            voiceAudioDelegate = nil
            playingVoiceMessageId = nil
            return
        }

        voiceAudioPlayer?.stop()
        voiceAudioPlayer = nil
        voiceAudioDelegate = nil
        playingVoiceMessageId = nil

        guard let media = message.media, media.kind == .voiceNote else { return }
        var resolvedPath = media.localPath
        if resolvedPath == nil, let fid = media.fileId, let tdlibProvider {
            downloadingMediaMessageId = message.id
            resolvedPath = try? await tdlibProvider.downloadMediaFile(fileId: fid, priority: 32, synchronous: true)
            downloadingMediaMessageId = nil
            if let resolvedPath {
                updateMessageMediaLocalPath(messageId: message.id, path: resolvedPath)
            }
        }

        guard let finalPath = resolvedPath, FileManager.default.fileExists(atPath: finalPath) else { return }
        let audioURL = URL(fileURLWithPath: finalPath)
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            let delegate = VoiceAudioDelegate { [weak self] in
                if self?.playingVoiceMessageId == message.id {
                    self?.playingVoiceMessageId = nil
                    self?.voiceAudioPlayer = nil
                    self?.voiceAudioDelegate = nil
                }
            }
            player.delegate = delegate
            player.prepareToPlay()
            player.play()
            self.voiceAudioDelegate = delegate
            self.voiceAudioPlayer = player
            self.playingVoiceMessageId = message.id
        } catch {
            // Fallback to opening in system/media viewer if format requires AVPlayer decoding
            print("AVAudioPlayer failed for \(audioURL.lastPathComponent): \(error)")
            let item = MediaViewerItem(
                id: message.id,
                title: "Voice Message · \(message.senderName)",
                fileId: media.fileId,
                localFileURL: audioURL,
                isVideo: true,
                expectedFileSize: media.fileSize,
                datacenterId: selectedChat?.datacenterId,
                originalDate: "\(message.dateGroup) \(message.timestamp)",
                platformName: "macOS · TDLib \(tdlibVersion ?? "1.8.70")"
            )
            activeMediaController = MediaViewerController(item: item)
            activeMediaViewerItem = item
        }
    }

    private func hydrateVisibleMedia(for chatId: String) async {
        guard let tdlibProvider else { return }
        // Prioritize newest messages first so photos/thumbnails on screen appear immediately
        let snapshot = Array(messages.reversed())
        for msg in snapshot {
            guard selectedChatId == chatId else { return }
            guard let media = msg.media else { continue }

            // Photos & stickers: download the primary image directly
            if (media.kind == .photo || media.kind == .sticker),
               media.localPath == nil,
               let fileId = media.fileId {
                if let path = try? await tdlibProvider.downloadMediaFile(fileId: fileId, priority: 24, synchronous: true),
                   selectedChatId == chatId,
                   let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                    messages[idx].media?.localPath = path
                }
            }

            // Videos / animations / video notes / documents: download thumbnail so cards show rich previews
            if media.thumbnailLocalPath == nil,
               let thumbId = media.thumbnailFileId {
                if let path = try? await tdlibProvider.downloadMediaFile(fileId: thumbId, priority: 20, synchronous: true),
                   selectedChatId == chatId,
                   let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                    messages[idx].media?.thumbnailLocalPath = path
                }
            }
        }

        // Pre-load the first 1.5 MB of the newest 6 videos/animations for fast playback start
        var preloadedCount = 0
        for msg in snapshot {
            guard selectedChatId == chatId, preloadedCount < 6 else { return }
            guard let media = msg.media,
                  (media.kind == .video || media.kind == .animation || media.kind == .videoNote),
                  media.localPath == nil,
                  let fileId = media.fileId else {
                continue
            }
            await tdlibProvider.preloadFilePrefix(fileId: fileId, bytes: 1_572_864)
            preloadedCount += 1
        }
    }

    private func hydrateAvatars() async {
        guard let tdlibProvider else { return }
        // Active account avatar
        if let accIdx = accounts.firstIndex(where: { $0.isActive }),
           accounts[accIdx].avatarLocalPath == nil,
           let fid = accounts[accIdx].avatarFileId {
            if let path = try? await tdlibProvider.downloadMediaFile(fileId: fid, priority: 18, synchronous: true) {
                accounts[accIdx].avatarLocalPath = path
            }
        }
        // Top visible chat avatars (first 25 chats)
        let chatIdsAndFiles: [(String, Int32)] = chats.prefix(25).compactMap { c in
            guard c.avatarLocalPath == nil, let fid = c.avatarFileId else { return nil }
            return (c.id, fid)
        }
        for (cid, fid) in chatIdsAndFiles {
            if let path = try? await tdlibProvider.downloadMediaFile(fileId: fid, priority: 14, synchronous: true),
               let idx = chats.firstIndex(where: { $0.id == cid }) {
                chats[idx].avatarLocalPath = path
            }
        }
    }

    public func sendCurrentMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chatId = selectedChatId, let telegramService else { return }

        let replySnippet = replyingToMessage?.id
        inputText = ""
        replyingToMessage = nil

        do {
            let msg: Message
            if let tdlibProvider {
                msg = try await tdlibProvider.sendMessageInTopic(
                    chatId: chatId,
                    text: text,
                    replyTo: replySnippet,
                    topicId: selectedTopicId
                )
            } else {
                msg = try await telegramService.sendMessage(chatId: chatId, text: text, replyTo: replySnippet)
            }
            messages.append(msg)
        } catch {
            print("Error sending message: \(error)")
        }
    }

    public func sendAttachment(fileURL: URL) async {
        guard let chatId = selectedChatId, let tdlibProvider else { return }
        let caption = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        do {
            let msg = try await tdlibProvider.sendDocument(chatId: chatId, fileURL: fileURL, caption: caption, topicId: selectedTopicId)
            messages.append(msg)
        } catch {
            print("Error sending attachment: \(error)")
        }
    }

    public func toggleReaction(messageId: String, emoji: String) async {
        guard let chatId = selectedChatId, let telegramService else { return }
        do {
            let newReactions = try await telegramService.toggleReaction(messageId: messageId, emoji: emoji, in: chatId)
            if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                messages[idx].reactions = newReactions
            }
        } catch {
            print("Error toggling reaction: \(error)")
        }
    }

    public func toggleProxy(_ proxyId: String) {
        var selected: ProxyConfig? = nil
        for idx in 0..<proxies.count {
            let enable = (proxies[idx].id == proxyId)
            proxies[idx].isEnabled = enable
            if enable { selected = proxies[idx] }
        }
        isProxyEnabled = (selected != nil)
        if let selected, let tdlibProvider {
            Task {
                try? await tdlibProvider.applyProxy(selected, enable: true)
            }
        }
    }

    public func disableProxy() {
        for idx in 0..<proxies.count {
            proxies[idx].isEnabled = false
        }
        isProxyEnabled = false
        if let tdlibProvider {
            Task {
                try? await tdlibProvider.disableActiveProxy()
            }
        }
    }

    public func switchAccount(_ accountId: String) {
        activeAccountId = accountId
        for idx in 0..<accounts.count {
            accounts[idx].isActive = (accounts[idx].id == accountId)
        }
    }

    public func checkUpdates() async {
        isCheckingForUpdates = true
        updateErrorMessage = nil
        updateStatusMessage = nil
        let info = await updateService.checkForUpdates(includePrereleases: installBetaVersions)
        updateInfo = info
        if info.hasUpdate {
            updateStatusMessage = "Update available: Aethergram v\(info.latestVersion)"
        } else {
            updateStatusMessage = "Aethergram v\(info.currentVersion) is up to date (checked \(AethergramUpdateService.githubOwner)/\(AethergramUpdateService.githubRepo))."
        }
        isCheckingForUpdates = false
    }

    public func downloadAndStageUpdate() async {
        guard let info = updateInfo else { return }
        isDownloadingUpdate = true
        updateErrorMessage = nil
        defer { isDownloadingUpdate = false }
        do {
            let stagedURL = try await updateService.downloadAndStageRelease(info)
            stagedUpdateFileURL = stagedURL
            updateStatusMessage = "Staged verified release at \(stagedURL.lastPathComponent)."
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([stagedURL])
            #endif
        } catch {
            updateErrorMessage = error.localizedDescription
        }
    }
}
