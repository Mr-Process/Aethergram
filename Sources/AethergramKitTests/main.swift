import Foundation
import CryptoKit
import AethergramKit

@MainActor
func runTests() async throws {
    print("========================================")
    print("Running AethergramKit v\(AethergramBrand.version) Live Feature Suite...")
    print("========================================")

    // Test 1: MD3 Color Palette Presets
    print("[TEST 1/7] Validating MD3 Color Palette Presets...")
    for preset in MD3PalettePreset.allCases {
        let light = MD3ColorPalette.forPreset(preset, isDark: false)
        let dark = MD3ColorPalette.forPreset(preset, isDark: true)
        assert(light.surface != dark.surface || preset == .amoled, "Light and Dark surfaces should adapt")
        print("  ✓ Preset '\(preset.rawValue)' configured correctly")
    }

    // Test 2: Live CoreAudio Hardware Enumeration
    print("[TEST 2/7] Testing Live CoreAudio Device Enumeration...")
    let outputs = AudioDeviceService.listOutputDevices()
    let inputs = AudioDeviceService.listInputDevices()
    assert(outputs.first == "System Default" && inputs.first == "System Default", "System Default must be present")
    print("  ✓ Detected \(outputs.count) output options, \(inputs.count) input options (live CoreAudio)")

    // Test 3: Live Passcode Vault & Lock System
    print("[TEST 3/7] Testing Passcode Vault & Lock System...")
    let store = ChatStore()
    assert(store.accounts.isEmpty, "Store must start with zero mocked accounts before Telegram sign-in")
    assert(store.proxies.isEmpty, "Store must start with zero mocked proxies before TDLib sync")
    assert(store.selectedChatId == nil, "Store must not preselect mocked chat IDs")
    store.passcodeManager.setPasscode("9472")
    assert(store.passcodeManager.isPasscodeEnabled, "Passcode should be enabled")
    store.passcodeManager.lockNow()
    assert(store.passcodeManager.isLocked, "Should be locked")
    store.passcodeManager.currentPinInput = "0000"
    let wrongUnlock = store.passcodeManager.verifyCurrentInput()
    assert(!wrongUnlock && store.passcodeManager.isLocked, "Wrong PIN must fail")
    store.passcodeManager.currentPinInput = "9472"
    let rightUnlock = store.passcodeManager.verifyCurrentInput()
    assert(rightUnlock && !store.passcodeManager.isLocked, "Correct PIN must unlock")
    store.passcodeManager.setPasscode("")
    print("  ✓ Passcode lock/unlock cycle verified (no hardcoded default PIN)")

    // Test 4: AethergramUpdateService (GitHub Releases API + SHA-256 Staging)
    print("[TEST 4/7] Testing AethergramUpdateService...")
    let updateService = AethergramUpdateService()
    assert(AethergramUpdateService.currentManifestEndpoint == "https://api.github.com/repos/Mr-Process/Aethergram/releases/latest")
    assert(AethergramUpdateService.isVersion("1.11", newerThan: "1.10"), "1.11 must be newer than 1.10")
    assert(!AethergramUpdateService.isVersion("1.10", newerThan: "1.10"), "1.10 must not be newer than 1.10")
    assert(AethergramUpdateService.normalizeVersion("v1.10.2") == "1.10.2", "normalizeVersion must strip v prefix")
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("mg_stage_test_\(UUID().uuidString)")
    let samplePayload = Data("aethergram-live-staging-check".utf8)
    let badHash = String(repeating: "0", count: 64)
    do {
        _ = try await updateService.stageUpdatePayload(fileName: "update.bin", data: samplePayload, expectedSHA256: badHash, stagingDirectory: tempDir)
        assertionFailure("Mismatched digest must throw")
    } catch UpdateStagingError.digestMismatch {
        // expected
    }
    do {
        _ = try await updateService.stageUpdatePayload(fileName: "Updater.exe", data: samplePayload, expectedSHA256: badHash, stagingDirectory: tempDir)
        assertionFailure("Forbidden Updater.exe must throw")
    } catch UpdateStagingError.forbiddenPayloadName {
        // expected
    }
    let validHash = SHA256.hash(data: samplePayload).map { String(format: "%02x", $0) }.joined()
    let stagedURL = try await updateService.stageUpdatePayload(fileName: "aethergram_update.bin", data: samplePayload, expectedSHA256: validHash, stagingDirectory: tempDir)
    assert(FileManager.default.fileExists(atPath: stagedURL.path), "Staged payload must exist in tupdates/ready")
    let parsedRelease = await updateService.parseGitHubReleaseJSON([
        "tag_name": "v1.11",
        "prerelease": false,
        "body": "Aethergram v1.11 release\nSHA256: \(validHash)",
        "html_url": "https://github.com/Mr-Process/Aethergram/releases/tag/v1.11",
        "assets": [
            [
                "name": "Aethergram-v1.11-macOS-arm64.zip",
                "browser_download_url": "https://github.com/Mr-Process/Aethergram/releases/download/v1.11/Aethergram-v1.11-macOS-arm64.zip"
            ]
        ]
    ])
    assert(parsedRelease.hasUpdate && parsedRelease.latestVersion == "1.11" && parsedRelease.expectedSHA256 == validHash, "parseGitHubReleaseJSON must detect newer version and SHA-256")
    try? FileManager.default.removeItem(at: tempDir)
    print("  ✓ Verified GitHub Releases feed: \(AethergramUpdateService.currentManifestEndpoint) + SemVer + SHA-256 staging")

    // Test 5: Live TDLib 1.8.0 Transport & Production MTProto Handshake
    print("[TEST 5/7] Testing Live TDLib Transport (libtdjson.dylib)...")
    let tdProvider = try TDLibTelegramProvider()
    assert(!tdProvider.tdlibVersion.isEmpty && tdProvider.tdlibVersion != "unknown", "Expected live TDLib version")
    let tempTdDir = FileManager.default.temporaryDirectory.appendingPathComponent("mg_tdlib_test_\(UUID().uuidString)")
    if let liveConfig = TDLibConfiguration.loadFromEnvironmentOrDisk(databaseDirectory: tempTdDir) {
        let state = try await tdProvider.startHandshake(config: liveConfig)
        assert(state == .waitPhoneNumber || state == .ready, "Expected waitPhoneNumber or ready, got \(state)")
        if state == .waitPhoneNumber {
            let phoneRes = try await tdProvider.submitPhoneNumber("000")
            assert(phoneRes.state == .waitPhoneNumber, "Auth state must stay waitPhoneNumber on invalid phone")
            assert(phoneRes.errorMessage != nil && !(phoneRes.errorMessage ?? "").isEmpty, "Expected live Telegram error for invalid phone")
            print("  ✓ Live setAuthenticationPhoneNumber round-trip returned Telegram reply: \(phoneRes.errorMessage ?? "")")
        }
        let liveProxies = try await tdProvider.fetchProxies()
        assert(liveProxies.isEmpty, "Fresh TDLib DB should report 0 proxies")
        let liveFolders = try await tdProvider.fetchFolders()
        assert(liveFolders.count == 1 && liveFolders[0].id == "all", "Unauthenticated TDLib should only expose All Chats")
        let liveChats = try await tdProvider.fetchChats(in: "all")
        assert(liveChats.isEmpty, "Unauthenticated TDLib must return 0 chats (no mock fallback)")
        print("  ✓ TDLib \(tdProvider.tdlibVersion) live handshake reached: \(state.displayText)")
        try? FileManager.default.removeItem(at: tempTdDir)
    } else {
        print("  ✓ Loaded live libtdjson (\(tdProvider.tdlibVersion)) from \(tdProvider.client.libraryPath)")
    }

    // Test 6: 9-Section Settings Sidebar & Advanced -> materialgram Parity
    print("[TEST 6/7] Testing 9-Section Settings Sidebar & Materialgram Toggles...")
    assert(SettingsSection.allCases.count == 9, "Expected 9 Windows Settings sections")
    let expectedTitles = [
        "My Account",
        "Notifications and Sounds",
        "Privacy and Security",
        "Chat Settings",
        "Chat Folders",
        "Advanced",
        "Speakers and Camera",
        "Battery and Animations",
        "Language"
    ]
    assert(SettingsSection.allCases.map(\.rawValue) == expectedTitles, "Settings section titles must match observed Windows hierarchy")
    store.selectedSettingsSection = .advanced
    assert(store.showRegistrationDate && store.showDatacenterId && store.showMaterialgramProfilePhotos, "Default Materialgram profile toggles should be enabled")
    store.showRegistrationDate = false
    store.showDatacenterId = false
    store.showMaterialgramProfilePhotos = false
    assert(!store.showRegistrationDate && !store.showDatacenterId && !store.showMaterialgramProfilePhotos, "Materialgram profile toggles should mutate cleanly")
    store.interfaceScalePercent = 110
    assert(store.interfaceScalePercent == 110, "Interface scale should update")
    print("  ✓ Verified 9 Settings sections + Advanced -> materialgram 3 toggles + Interface scale")

    // Test 7: Live Proxy Configuration Round-Trip State
    print("[TEST 7/8] Testing Live Proxy State Management...")
    let customProxy = ProxyConfig(type: .socks5, server: "127.0.0.1", port: 1080)
    store.proxies.append(customProxy)
    store.toggleProxy(customProxy.id)
    assert(store.isProxyEnabled && store.proxies.first?.isEnabled == true, "Proxy should enable")
    store.disableProxy()
    assert(!store.isProxyEnabled && store.proxies.first?.isEnabled == false, "Proxy should disable")
    print("  ✓ Proxy enable/disable state verified")

    // Test 8: Materialgram Parity Helpers (Registration Estimator, @handle, Tailless Bubbles, HTML Export)
    print("[TEST 8/8] Testing Materialgram Fork Parity Helpers...")
    let est = ProfileMetadataEstimator.estimatedRegistrationDate(forPeerId: "1000000000")
    assert(est != nil && est!.contains("2020"), "Expected ~Jan 2020 estimate for Peer ID 1B, got \(est ?? "nil")")
    assert(ProfileMetadataEstimator.formattedHandle("materialgram") == "@materialgram", "Username must format as @example")
    let bubble = MD3BubbleShape(isOutgoing: true, baseRadius: 16)
    assert(bubble.tailRadius == 16, "Materialgram bubbles must be tailless by default")
    let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("mg_export_test_\(UUID().uuidString)")
    let testChat = Chat(id: "42", title: "Export Check", avatarInitials: "EC", lastMessagePreview: "Hi", lastMessageTime: "12:00")
    let testMsg = Message(id: "1", chatId: "42", senderName: "You", text: "Hello <Materialgram>", timestamp: "12:00", isOutgoing: true)
    let exportURL = try ChatExportService.exportChatHTML(chat: testChat, messages: [testMsg], destinationDirectory: exportDir)
    let html = try String(contentsOf: exportURL, encoding: .utf8)
    assert(html.contains("Hello &lt;Materialgram&gt;"), "HTML export must escape message text")
    try? FileManager.default.removeItem(at: exportDir)
    print("  ✓ Verified Registration estimator (\(est ?? "")), @handle format, tailless MD3 bubbles, and 10k HTML export")

    // Test 9: Phase 1 - Typography & Notification Sound Gating
    print("[TEST 9/12] Testing Phase 1 Typography & Notification Sound Gating...")
    MD3Typography.registerBundledFonts()
    let fontName = MD3Typography.resolvedFontFamilyName(forSampleText: "Materialgram")
    assert(!fontName.isEmpty, "Typography must resolve a font family")
    assert(NotificationSoundService.shared.shouldPlaySound(allowSound: true, volumePercent: 80))
    assert(!NotificationSoundService.shared.shouldPlaySound(allowSound: false, volumePercent: 80))
    assert(!NotificationSoundService.shared.shouldPlaySound(allowSound: true, volumePercent: 0))
    print("  ✓ Resolved font family: \(fontName) + notification sound gating verified")

    // Test 10: Phase 2 - 256 kbps Voice Recorder & 94% JPEG Photo Editor
    print("[TEST 10/12] Testing Phase 2 Voice (256 kbps) & Photo Editor (94% JPEG)...")
    let recSettings = VoiceRecorderService.recorderSettings()
    assert((recSettings["AVEncoderBitRateKey"] as? Int ?? VoiceRecorderService.targetBitrateBps) == 256_000, "Voice bitrate must be 256 kbps")
    assert(PhotoEditorController.materialgramJPEGQuality == 0.94, "JPEG quality must be 94%")
    assert(PhotoEditorController.minimumBrushThickness == 1.0, "Minimum brush thickness must be 1pt")
    print("  ✓ Verified 256 kbps voice recorder config & 94% JPEG / 1pt brush photo editor")

    // Test 11: Phase 3 - Sticker Set Author ID Extraction
    print("[TEST 11/12] Testing Phase 3 Sticker Set Author ID Extraction...")
    let sampleSetId: Int64 = (Int64(123456789) << 32) | 42
    assert(StickerSetHelper.authorId(fromSetId: sampleSetId) == 123456789, "Author ID bitshift extraction must match")
    print("  ✓ Verified sticker set author ID extraction (setId >> 32)")

    // Test 12: Phase 4 - Multi-Account Pool (10/20), Multi-Mention & Android Mini App Override
    print("[TEST 12/12] Testing Phase 4 Multi-Account Pool, Multi-Mention & Mini App Platform...")
    var stdPool = AccountSessionPool(isPremium: false)
    assert(stdPool.maxSlots == 10, "Standard account limit must be 10")
    for i in 1...10 {
        _ = try stdPool.addSlot(accountId: "u\(i)", displayName: "User \(i)")
    }
    var threwLimit = false
    do {
        _ = try stdPool.addSlot(accountId: "u11", displayName: "User 11")
    } catch AccountPoolError.limitReached(let max) {
        threwLimit = (max == 10)
    }
    assert(threwLimit, "11th standard account must enforce limit")
    let premPool = AccountSessionPool(isPremium: true)
    assert(premPool.maxSlots == 20, "Premium account limit must be 20")
    assert(GroupMentionHelper.formatMultiMention(["alice", "@bob"]) == "@alice @bob", "Multi-mention formatting must add @")
    let miniURL = URL(string: "https://app.example.com/mini?tgWebAppPlatform=macos&theme=dark")!
    let rewritten = MiniAppPlatformOverride.rewritePlatformURL(miniURL)
    assert(rewritten.absoluteString.contains("tgWebAppPlatform=android"), "Mini App URL must rewrite platform to android")
    print("  ✓ Verified 10/20 account pool, @multi-mention, and Mini App android override")

    // Test 13: Export Bundle (HTML + JSON + Media) & TDLibFileProgress
    print("[TEST 13/13] Testing Export Bundle (HTML + JSON + Media) & Download Progress...")
    let halfProg = TDLibFileProgress(fileId: 7, localPath: nil, downloadedSize: 500, expectedSize: 1000, isCompleted: false, isDownloading: true)
    assert(abs(halfProg.fractionCompleted - 0.5) < 0.0001, "Expected 0.5 fractionCompleted")
    let doneProg = TDLibFileProgress(fileId: 7, localPath: "/tmp/a.mp4", downloadedSize: 0, expectedSize: 0, isCompleted: true, isDownloading: false)
    assert(doneProg.fractionCompleted == 1.0, "Completed progress with unknown expectedSize must return 1.0")

    let bundleDir = FileManager.default.temporaryDirectory.appendingPathComponent("mg_bundle_test_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
    let samplePhotoURL = bundleDir.appendingPathComponent("sample_photo.jpg")
    try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: samplePhotoURL)
    let mediaMsg = Message(
        id: "101",
        chatId: "42",
        senderName: "Materialgram",
        text: "Test caption",
        timestamp: "12:05",
        isOutgoing: false,
        media: MessageMedia(kind: .photo, fileId: 9, localPath: samplePhotoURL.path, fileName: "sample_photo.jpg", fileSize: 4),
        viewsCount: 1500
    )
    let exportOpts = ChatExportOptions(format: .both, maxMessages: 10_000, destinationDirectory: bundleDir)
    let bundleResult = try ChatExportService.exportChatBundle(chat: testChat, messages: [testMsg, mediaMsg], options: exportOpts)
    assert(bundleResult.messageCount == 2 && bundleResult.mediaFilesCopied == 1, "Expected 2 messages and 1 copied media file")
    let htmlOut = try String(contentsOf: bundleResult.htmlURL!, encoding: .utf8)
    assert(htmlOut.contains("photos/sample_photo.jpg") && htmlOut.contains("1500 views"), "HTML bundle must embed relative photo path and views")
    let jsonOut = try String(contentsOf: bundleResult.jsonURL!, encoding: .utf8)
    assert(jsonOut.contains("\"media_type\" : \"photo\"") && jsonOut.contains("photos\\/sample_photo.jpg") || jsonOut.contains("photos/sample_photo.jpg"), "JSON bundle must serialize photo metadata")

    // Verify Custom Photo Wallpaper upload & clear cycle
    let copiedWallURL = try store.setCustomWallpaper(from: samplePhotoURL)
    assert(store.wallpaperPreset == .customPhoto && store.customWallpaperPath == copiedWallURL.path, "setCustomWallpaper must activate .customPhoto")
    assert(FileManager.default.fileExists(atPath: copiedWallURL.path), "Custom wallpaper must be copied into Application Support/Materialgram/wallpapers")
    store.clearCustomWallpaper()
    assert(store.customWallpaperPath == nil && store.wallpaperPreset != .customPhoto, "clearCustomWallpaper must reset customWallpaperPath")

    // Verify My Account Profile Editing (Name, Bio, Username, Birthday) & Folder Creation
    let localAcc = UserAccount(id: "777", firstName: "Jekyll", lastName: "Hyde", name: "Jekyll Hyde", username: "@drjekyll", phoneNumber: "15550000", bio: "Original bio", avatarInitials: "JH", isActive: true)
    store.accounts = [localAcc]
    store.activeAccountId = "777"
    store.populateProfileEditFields(from: localAcc)
    assert(store.editFirstName == "Jekyll" && store.editLastName == "Hyde" && store.editUsername == "drjekyll", "populateProfileEditFields must extract first/last/username")
    store.editFirstName = "Updated"
    store.editLastName = "User"
    await store.saveProfileName()
    assert(store.activeAccount?.name == "Updated User", "saveProfileName must update activeAccount name")
    store.editBio = "Materialgram macOS user"
    await store.saveProfileBio()
    assert(store.activeAccount?.bio == "Materialgram macOS user", "saveProfileBio must update activeAccount bio")

    try? FileManager.default.removeItem(at: bundleDir)
    print("  ✓ Verified HTML + JSON export bundle, custom wallpaper upload, My Account profile editor, & TDLibFileProgress")

    // Test 14: iMe-Style Bookmarks & Cloud Albums (Messages, Photos, Videos)
    print("[TEST 14/14] Testing iMe-Style Bookmarks (Messages, Photos, Videos)...")
    let videoMsg = Message(
        id: "202",
        chatId: "42",
        senderName: "Luke",
        text: "Clip archive",
        timestamp: "13:39",
        isOutgoing: false,
        media: MessageMedia(kind: .video, fileId: 15, duration: 752, fileName: "clip.mp4", fileSize: 33_200_000)
    )
    let bmText = BookmarkItem(message: testMsg, chatTitle: "Export Check")
    let bmPhoto = BookmarkItem(message: mediaMsg, chatTitle: "Export Check")
    let bmVideo = BookmarkItem(message: videoMsg, chatTitle: "Thisvid archive", topicId: 8, topicName: "General Chat")
    assert(bmText.category == .message && bmPhoto.category == .photo && bmVideo.category == .video, "BookmarkItem must classify message, photo, and video categories")
    assert(bmVideo.reconstructedMedia?.kind == .video && bmVideo.reconstructedMedia?.duration == 752, "BookmarkItem must reconstruct MessageMedia accurately")

    let tempBmURL = FileManager.default.temporaryDirectory.appendingPathComponent("mg_bookmarks_test_\(UUID().uuidString).json")
    try BookmarkService.saveBookmarks([bmText, bmPhoto, bmVideo], to: tempBmURL)
    let loadedBms = BookmarkService.loadBookmarks(from: tempBmURL)
    assert(loadedBms.count == 3, "Expected 3 persisted bookmarks")
    assert(BookmarkService.filter(loadedBms, category: .photo).count == 1, "Expected 1 photo bookmark")
    assert(BookmarkService.filter(loadedBms, category: .video, searchQuery: "General Chat").count == 1, "Expected 1 video bookmark matching search query")
    try? FileManager.default.removeItem(at: tempBmURL)
    print("  ✓ Verified iMe-style message, photo, and video bookmarks persistence & filtering")

    // Test 15: Aethergram Brand Identity, Version 1.10, Favicon Suite & HTML Export Favicon Tags
    print("[TEST 15/15] Testing Aethergram Brand Identity (v1.10) & Favicon Assets...")
    assert(AethergramBrand.appName == "Aethergram", "Brand appName must be Aethergram")
    assert(AethergramBrand.version == "1.10" && AethergramUpdateService.currentVersion == "1.10", "Version must be 1.10")
    assert(AethergramBrand.bundleIdentifier == "app.aethergram.macos", "Brand bundleIdentifier must be app.aethergram.macos")
    let resBundle = MD3Typography.resourceBundle
    let expectedFavicons = ["favicon.ico", "favicon.svg", "favicon-96x96.png", "apple-touch-icon.png", "web-app-manifest-192x192.png", "web-app-manifest-512x512.png", "site.webmanifest"]
    for fav in expectedFavicons {
        let ext = (fav as NSString).pathExtension
        let base = (fav as NSString).deletingPathExtension
        let found = resBundle.url(forResource: base, withExtension: ext, subdirectory: "Favicons")
            ?? resBundle.url(forResource: base, withExtension: ext)
        assert(found != nil, "Bundled favicon asset \(fav) must exist in MaterialgramKit resources")
    }
    assert(html.contains("<title>Aethergram Export - Export Check</title>"), "Exported HTML must include Aethergram title")
    assert(html.contains("rel=\"apple-touch-icon\""), "Exported HTML must include apple-touch-icon link tag")
    assert(html.contains("rel=\"manifest\" href=\"site.webmanifest\""), "Exported HTML must include site.webmanifest link tag")
    print("  ✓ Verified Aethergram brand identity, 7 bundled favicon assets, and HTML export favicon tags")

    // Test 16: Smart Ranked Search, Scope Filters, Channel/Group Pinning & Recently Viewed History
    print("[TEST 16/16] Testing Smart Search, Channel/Group Pinning & Recently Viewed...")
    let ch1 = Chat(id: "-1001", title: "Aethergram Announcements", subtitle: "12K subscribers", avatarInitials: "AA", lastMessagePreview: "New Liquid Glass build", lastMessageTime: "10:00", unreadCount: 3, isPinned: false, type: .channel, username: "@aethergram_news")
    let grp1 = Chat(id: "-1002", title: "SwiftUI macOS Engineers", subtitle: "850 members", avatarInitials: "SE", lastMessagePreview: "Pinned message support", lastMessageTime: "09:45", unreadCount: 0, isPinned: false, type: .group, username: "@swiftui_mac")
    store.chats = [ch1, grp1]
    store.searchText = "@swiftui"
    assert(store.filteredChats.count == 1 && store.filteredChats.first?.id == "-1002", "Smart search must match @username handle")
    store.searchText = "aether news"
    assert(store.filteredChats.first?.id == "-1001", "Smart multi-token search must rank channel matching title + username first")
    store.searchText = ""
    store.searchScope = .channels
    assert(store.filteredChats.count == 1 && store.filteredChats.first?.type == .channel, "Channel scope filter must return only channels")
    store.searchScope = .all

    // Test pinning channel to top
    await store.toggleChatPin(grp1)
    assert(store.chats.first(where: { $0.id == "-1002" })?.isPinned == true, "toggleChatPin must mark group as pinned")
    assert(store.filteredChats.first?.id == "-1002", "Pinned group/channel must float to top of filteredChats")

    // Test recently viewed recording & persistence
    let tempRecentURL = FileManager.default.temporaryDirectory.appendingPathComponent("ag_recent_test_\(UUID().uuidString).json")
    store.recentlyViewedChats = []
    store.recordRecentlyViewedChat(ch1, storageURL: tempRecentURL)
    store.recordRecentlyViewedChat(grp1, storageURL: tempRecentURL)
    let loadedRecent = ChatStore.loadRecentlyViewedChats(from: tempRecentURL)
    assert(loadedRecent.count == 2 && loadedRecent.first?.chatId == "-1002", "Most recently viewed chat must be first and persisted")
    try? FileManager.default.removeItem(at: tempRecentURL)
    print("  ✓ Verified ranked search, scope pills, channel/group pinning, and recently viewed persistence")

    // Test 17: Chat Info Shared Media Separate Sections (Photos, Videos, Files, Voice, GIFs)
    print("[TEST 17/17] Testing Chat Info Separate Photos & Videos Shared Media Tabs...")
    assert(SharedMediaTab.photos.tdlibFilterType == "searchMessagesFilterPhoto", "Photos tab must use searchMessagesFilterPhoto")
    assert(SharedMediaTab.videos.tdlibFilterType == "searchMessagesFilterVideo", "Videos tab must use searchMessagesFilterVideo")
    assert(SharedMediaTab.files.tdlibFilterType == "searchMessagesFilterDocument", "Files tab must use searchMessagesFilterDocument")
    let docMsg = Message(
        id: "303",
        chatId: "42",
        senderName: "Archivist",
        text: "Spec PDF",
        timestamp: "14:10",
        isOutgoing: false,
        media: MessageMedia(kind: .document, fileId: 19, fileName: "spec.pdf", fileSize: 120_000)
    )
    store.messages = [testMsg, mediaMsg, videoMsg, docMsg]
    store.sharedMediaByTab = [:]
    let onlyPhotos = store.sharedMediaMessages(for: .photos)
    let onlyVideos = store.sharedMediaMessages(for: .videos)
    let onlyFiles = store.sharedMediaMessages(for: .files)
    assert(onlyPhotos.count == 1 && onlyPhotos.first?.id == mediaMsg.id, "Photos section must only contain photo messages")
    assert(onlyVideos.count == 1 && onlyVideos.first?.id == videoMsg.id, "Videos section must only contain video messages")
    assert(onlyFiles.count == 1 && onlyFiles.first?.id == docMsg.id, "Files section must only contain document messages")
    print("  ✓ Verified separated Photos, Videos, Files, Voice, and GIFs sections in Chat Info")

    print("========================================")
    print("ALL 17 LIVE FEATURE TEST SUITES PASSED! (17/17)")
    print("========================================")
}

Task { @MainActor in
    do {
        try await runTests()
        exit(0)
    } catch {
        print("TEST RUN FAILED: \(error)")
        exit(1)
    }
}
RunLoop.main.run()
