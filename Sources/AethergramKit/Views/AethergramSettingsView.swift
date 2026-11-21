import SwiftUI

public struct AethergramSettingsView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette

    private let supportedLanguages: [String] = [
        "English",
        "Español",
        "Deutsch",
        "Français",
        "Italiano",
        "Português (Brasil)",
        "Русский",
        "Українська",
        "中文 (简体)",
        "한국어",
        "日本語"
    ]

    public init(store: ChatStore, palette: MD3ColorPalette) {
        self.store = store
        self.palette = palette
    }

    public var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: 245)
                .background(palette.surfaceContainerLow)

            Divider()

            VStack(spacing: 0) {
                detailHeader
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        activeSectionContent
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surface)
        }
        .frame(minWidth: 780, idealWidth: 840, minHeight: 580, idealHeight: 640)
    }

    // MARK: - Left Sidebar (9 Observed Windows Settings Sections + Interface Scale)
    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            // Account Summary Header
            if let acc = store.activeAccount {
                HStack(spacing: 12) {
                    MD3AvatarView(
                        localPath: acc.avatarLocalPath,
                        initials: acc.avatarInitials,
                        hue: acc.avatarHue,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(acc.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(palette.onSurface)
                            .lineLimit(1)
                        Text(acc.username)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider()

            // 9 Core Sections
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }

            Divider()

            // Inline Interface Scale
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Interface scale")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(store.interfaceScalePercent))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.primary)
                    if Int(store.interfaceScalePercent) != 100 {
                        Button("Reset") {
                            store.interfaceScalePercent = 100
                        }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundColor(palette.primary)
                    }
                }
                Slider(value: $store.interfaceScalePercent, in: 75...150, step: 5)
                    .tint(palette.primary)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Footer Metadata
            HStack(spacing: 8) {
                AethergramLogoView(size: 18)
                Text("\(AethergramBrand.appName) v\(MaterialgramUpdateService.currentVersion)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("macOS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(palette.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func sidebarButton(for section: SettingsSection) -> some View {
        let isSelected = store.selectedSettingsSection == section
        return Button {
            store.selectedSettingsSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? palette.primary : .secondary)
                    .frame(width: 20)

                Text(section.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? palette.onSurface : palette.onSurface.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                if let badge = sidebarBadge(for: section) {
                    Text(badge)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? palette.primary.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarBadge(for section: SettingsSection) -> String? {
        switch section {
        case .language:
            return store.appLanguage
        case .chatFolders:
            return "\(store.folders.count)"
        case .advanced:
            return store.isProxyEnabled ? "Proxy" : nil
        default:
            return nil
        }
    }

    // MARK: - Detail Header
    private var detailHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: store.selectedSettingsSection.iconName)
                .font(.system(size: 18))
                .foregroundColor(palette.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.selectedSettingsSection.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(palette.onSurface)
                Text(sectionSubtitle(for: store.selectedSettingsSection))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                store.showSettingsSheet = false
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.primary)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(palette.surface)
    }

    private func sectionSubtitle(for section: SettingsSection) -> String {
        switch section {
        case .myAccount: return "Manage your active profile and Telegram connection."
        case .notifications: return "Control alerts, sounds, badges, and Focus mode."
        case .privacy: return "Protect your chats with a passcode, Touch ID, and stealth options."
        case .chatSettings: return "Customize colors, wallpapers, message bubbles, and emoji."
        case .chatFolders: return "Organize your chats into sidebar folders."
        case .advanced: return "Configure proxies, \(AethergramBrand.appName) profile details, performance, and updates."
        case .speakersAndCamera: return "Choose audio devices and call preferences."
        case .batteryAndAnimations: return "Reduce power usage by pausing animations and autoplay."
        case .language: return "Set your display language and message translation options."
        }
    }

    // MARK: - Active Section Switcher
    @ViewBuilder
    private var activeSectionContent: some View {
        switch store.selectedSettingsSection {
        case .myAccount:
            myAccountSection
        case .notifications:
            notificationsSection
        case .privacy:
            privacySection
        case .chatSettings:
            chatSettingsSection
        case .chatFolders:
            chatFoldersSection
        case .advanced:
            advancedSection
        case .speakersAndCamera:
            speakersAndCameraSection
        case .batteryAndAnimations:
            batteryAndAnimationsSection
        case .language:
            languageSection
        }
    }

    // MARK: - 1. My Account (Full Profile Photo, Name, Username, Bio, Birthday & Account Editor)
    private var myAccountSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let acc = store.activeAccount {
                // Profile Hero & Photo Editor (`SetupPhoto` in settings_information.cpp)
                settingsCard(title: "Profile Photo and Identity") {
                    HStack(spacing: 16) {
                        MD3AvatarView(
                            localPath: acc.avatarLocalPath,
                            initials: acc.avatarInitials,
                            hue: acc.avatarHue,
                            size: 72
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(acc.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(palette.onSurface)

                            HStack(spacing: 10) {
                                if !acc.username.isEmpty {
                                    Button {
                                        ProfileMetadataEstimator.copyToClipboard(acc.username)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Text(acc.username)
                                                .font(.system(size: 12.5, weight: .medium))
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 10))
                                        }
                                        .foregroundColor(palette.primary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if !acc.phoneNumber.isEmpty {
                                    Text("+\(acc.phoneNumber.replacingOccurrences(of: "+", with: ""))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(spacing: 12) {
                                Button {
                                    ProfileMetadataEstimator.copyToClipboard(acc.id)
                                } label: {
                                    Label("ID: \(acc.id)", systemImage: "number")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                if store.showRegistrationDate,
                                   let regDate = ProfileMetadataEstimator.estimatedRegistrationDate(forPeerId: acc.id) {
                                    Label("Registered \(regDate)", systemImage: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Change Photo...") {
                                store.chooseAndUploadProfilePhoto()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(palette.primary)
                            .controlSize(.small)
                            .disabled(store.isSavingProfile)

                            if acc.avatarLocalPath != nil || acc.profilePhotoId != nil {
                                Button("Remove Photo") {
                                    Task { await store.removeCurrentProfilePhoto() }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(store.isSavingProfile)
                            }
                        }
                    }
                }

                // Edit Name, Username, Bio & Birthday (`SetupRows` & `SetupBio` in settings_information.cpp)
                settingsCard(title: "Edit Profile Information") {
                    // First & Last Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            TextField("First name", text: $store.editFirstName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Last name (optional)", text: $store.editLastName)
                                .textFieldStyle(.roundedBorder)
                            Button("Save Name") {
                                Task { await store.saveProfileName() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(palette.primary)
                            .controlSize(.small)
                            .disabled(store.isSavingProfile || store.editFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    Divider()

                    // Username
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Username")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !store.editUsername.isEmpty {
                                Text("t.me/\(store.editUsername.replacingOccurrences(of: "@", with: ""))")
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.primary)
                            }
                        }

                        HStack(spacing: 10) {
                            Text("@")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("username", text: $store.editUsername)
                                .textFieldStyle(.roundedBorder)
                            Button("Save Username") {
                                Task { await store.saveProfileUsername() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isSavingProfile)
                        }
                        Text("People can find you on Telegram by this public @username without knowing your phone number.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Bio (70-character limit matching settings_information.cpp kSaveBioTimeout)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bio")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(max(0, 70 - store.editBio.count)) characters remaining")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundColor(store.editBio.count > 70 ? .red : .secondary)
                        }

                        HStack(spacing: 10) {
                            TextField("Add a few words about yourself...", text: $store.editBio)
                                .textFieldStyle(.roundedBorder)
                            Button("Save Bio") {
                                Task { await store.saveProfileBio() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isSavingProfile)
                        }
                        Text("Any details such as age, occupation, or city. Example: 23 y.o. designer from San Francisco.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Birthday (`setBirthdate`)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date of Birth")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Day (1-31)", text: $store.editBirthDay)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                            TextField("Month (1-12)", text: $store.editBirthMonth)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            TextField("Year (optional)", text: $store.editBirthYear)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 115)
                            Spacer()
                            Button("Save Birthday") {
                                Task { await store.saveProfileBirthdate() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isSavingProfile)
                        }
                    }

                    if let status = store.profileStatusMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(status)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }

                    if let err = store.profileErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.system(size: 11.5))
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }
                .onAppear {
                    if store.editFirstName.isEmpty {
                        store.populateProfileEditFields(from: acc)
                    }
                }
            }

            settingsCard(title: "Accounts and Session") {
                if store.accounts.isEmpty {
                    Text("No Telegram account signed in. Connect with TDLib below to load your live profile.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.accounts) { acc in
                        HStack(spacing: 12) {
                            MD3AvatarView(
                                localPath: acc.avatarLocalPath,
                                initials: acc.avatarInitials,
                                hue: acc.avatarHue,
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(acc.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(acc.username.isEmpty ? "+\(acc.phoneNumber)" : acc.username)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if acc.id == store.activeAccountId {
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(palette.primary)
                            } else {
                                Button("Switch") {
                                    store.switchAccount(acc.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        if acc.id != store.accounts.last?.id {
                            Divider()
                        }
                    }

                    Divider()

                    HStack {
                        Button("Refresh Profile from Telegram") {
                            Task { await store.refreshMyAccountProfile() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button("Log Out") {
                            Task { await store.logOutCurrentAccount() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
            }

            settingsCard(title: "Telegram Connection (TDLib)") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TDLib \(store.tdlibVersion ?? "Unavailable") - Production DC")
                            .font(.system(size: 13, weight: .medium))
                        Text(store.tdlibAuthState.displayText)
                            .font(.system(size: 11))
                            .foregroundColor(store.tdlibAuthState == .ready ? .green : .secondary)
                    }
                    Spacer()
                    if store.tdlibAuthState == .unconfigured || store.tdlibAuthState == .connecting {
                        Button(store.tdlibAuthState == .connecting ? "Connecting..." : "Connect") {
                            Task { await store.connectTDLib() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .disabled(store.tdlibAuthState == .connecting)
                    } else if case .error = store.tdlibAuthState {
                        Button("Reconnect") {
                            Task { await store.connectTDLib() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                    }
                }

                if store.tdlibAuthState == .waitPhoneNumber {
                    HStack {
                        TextField("+1234567890", text: $store.authPhoneInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isSubmittingAuth)
                            .onSubmit {
                                Task { await store.submitTDLibPhone() }
                            }
                        Button {
                            Task { await store.submitTDLibPhone() }
                        } label: {
                            HStack(spacing: 6) {
                                if store.isSubmittingAuth {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(store.isSubmittingAuth ? "Sending..." : "Send code")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .disabled(store.isSubmittingAuth || store.authPhoneInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else if store.tdlibAuthState == .waitCode {
                    HStack {
                        TextField("Enter login code", text: $store.authCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isSubmittingAuth)
                            .onSubmit {
                                Task { await store.submitTDLibCode() }
                            }
                        Button {
                            Task { await store.submitTDLibCode() }
                        } label: {
                            HStack(spacing: 6) {
                                if store.isSubmittingAuth {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(store.isSubmittingAuth ? "Verifying..." : "Verify")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .disabled(store.isSubmittingAuth || store.authCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else if case .waitPassword = store.tdlibAuthState {
                    HStack {
                        SecureField("Enter cloud password", text: $store.authPasswordInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isSubmittingAuth)
                            .onSubmit {
                                Task { await store.submitTDLibPassword() }
                            }
                        Button {
                            Task { await store.submitTDLibPassword() }
                        } label: {
                            HStack(spacing: 6) {
                                if store.isSubmittingAuth {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(store.isSubmittingAuth ? "Unlocking..." : "Unlock")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .disabled(store.isSubmittingAuth || store.authPasswordInput.isEmpty)
                    }
                }

                if let err = store.authErrorMessage, !err.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 11.5))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - 2. Notifications and Sounds
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Global Settings") {
                toggleRow("Desktop notifications", subtitle: "Show macOS banners when new messages arrive.", isOn: $store.desktopNotifications)
                Divider()
                toggleRow("Allow sound", subtitle: "Play a sound for incoming messages.", isOn: $store.allowNotificationSound)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(store.notificationVolume))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $store.notificationVolume, in: 0...100, step: 5)
                        .tint(palette.primary)
                        .disabled(!store.allowNotificationSound)
                }
                Divider()
                toggleRow("Show sender name", subtitle: "Include the contact or group name in alerts.", isOn: $store.showNotificationName)
                Divider()
                toggleRow("Show message text", subtitle: "Include a message preview in alerts.", isOn: $store.showNotificationPreview)
            }

            settingsCard(title: "Badge Counter and System Integration") {
                toggleRow("Include muted chats in unread count", subtitle: "Count unread messages from muted chats in the dock badge.", isOn: $store.includeMutedInBadgeCount)
                Divider()
                toggleRow("Respect system Focus mode", subtitle: "Mute banners and sounds while macOS Focus is on.", isOn: $store.respectSystemFocusMode)
            }
        }
    }

    // MARK: - 3. Privacy and Security
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Security and Passcode") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local passcode lock")
                                .font(.system(size: 13, weight: .medium))
                            Text(store.passcodeManager.isPasscodeEnabled ? "Passcode protection is active." : "Lock \(AethergramBrand.appName) with a custom PIN or Touch ID.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if store.passcodeManager.isPasscodeEnabled {
                            Button("Disable PIN") {
                                store.passcodeManager.setPasscode("")
                                store.newPasscodeInput = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if !store.passcodeManager.isPasscodeEnabled {
                        HStack {
                            SecureField("Enter new PIN", text: $store.newPasscodeInput)
                                .textFieldStyle(.roundedBorder)
                            Button("Enable PIN") {
                                let trimmed = store.newPasscodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                store.passcodeManager.setPasscode(trimmed)
                                store.newPasscodeInput = ""
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.newPasscodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if store.passcodeManager.isPasscodeEnabled {
                        Toggle("Unlock with Touch ID", isOn: $store.passcodeManager.biometricEnabled)
                            .toggleStyle(.switch)
                            .tint(palette.primary)
                            .font(.system(size: 12))
                    }
                }
            }

            settingsCard(title: "Privacy") {
                toggleRow("Ghost mode", subtitle: "Hide your online status and typing indicators.", isOn: $store.ghostMode)
                Divider()
                toggleRow("Send read receipts", subtitle: "Mark incoming messages as read when you view them.", isOn: $store.showReadReceipts)
            }

            settingsCard(title: "Active Devices and Sessions") {
                HStack {
                    Text("Logged-in Telegram devices (\(store.activeSessions.count))")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(store.isLoadingSessions ? "Loading..." : "Refresh Sessions") {
                        Task { await store.refreshActiveSessions() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isLoadingSessions)
                }

                if store.activeSessions.isEmpty {
                    Text("Click Refresh Sessions to load your active Telegram devices via TDLib getActiveSessions.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.activeSessions) { session in
                        Divider()
                        HStack(spacing: 12) {
                            Image(systemName: session.isCurrent ? "laptopcomputer.and.iphone" : "desktopcomputer")
                                .font(.system(size: 16))
                                .foregroundColor(session.isCurrent ? palette.primary : .secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("\(session.deviceModel) · \(session.platform) \(session.systemVersion)")
                                        .font(.system(size: 12.5, weight: .semibold))
                                    if session.isCurrent {
                                        Text("This device")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(palette.primary.opacity(0.15))
                                            .foregroundColor(palette.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(session.applicationName) \(session.applicationVersion) • \(session.ipAddress) \(session.location)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !session.isCurrent {
                                Button("Terminate") {
                                    Task { await store.terminateActiveSession(session.id) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .onAppear {
                if store.activeSessions.isEmpty {
                    Task { await store.refreshActiveSessions() }
                }
            }
        }
    }

    // MARK: - 4. Chat Settings
    private var chatSettingsSection: some View {
        let threeCols = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Color Theme") {
                LazyVGrid(columns: threeCols, spacing: 10) {
                    ForEach(MD3PalettePreset.allCases) { preset in
                        let isSelected = store.palettePreset == preset
                        Button {
                            store.palettePreset = preset
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(preset.accentColor)
                                    .frame(width: 18, height: 18)

                                Text(preset.rawValue)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(palette.onSurface)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(preset.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? preset.accentColor.opacity(0.14) : palette.surfaceContainer)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isSelected ? preset.accentColor : palette.outlineVariant.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsCard(title: "Chat Wallpaper & Custom Photo") {
                // Live Wallpaper + Message Bubble Preview Window
                ZStack {
                    ConversationWallpaper(
                        preset: store.wallpaperPreset,
                        customPhotoPath: store.customWallpaperPath,
                        blurRadius: store.wallpaperBlurRadius,
                        dimming: store.wallpaperDimming,
                        showPattern: store.showWallpaperPattern,
                        palette: palette
                    )

                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AethergramBrand.appName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(palette.primary)
                                Text("Previewing \(store.wallpaperPreset.rawValue) wallpaper")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(palette.onBubbleIncoming)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.bubbleIncoming)
                            .clipShape(MD3BubbleShape(isOutgoing: false, baseRadius: store.bubbleCornerRadius, tailRadius: 4))
                            Spacer()
                        }

                        HStack {
                            Spacer()
                            Text("Corners: \(Int(store.bubbleCornerRadius))pt • Blur: \(Int(store.wallpaperBlurRadius))pt")
                                .font(.system(size: 12.5))
                                .foregroundColor(palette.onBubbleOutgoing)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(palette.bubbleOutgoing)
                                .clipShape(MD3BubbleShape(isOutgoing: true, baseRadius: store.bubbleCornerRadius, tailRadius: 4))
                        }
                    }
                    .padding(14)
                }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.outlineVariant.opacity(0.35), lineWidth: 1)
                )

                // Visual 3-Column Wallpaper Gallery Grid (Zero Segmented Text Wrapping)
                LazyVGrid(columns: threeCols, spacing: 10) {
                    ForEach(WallpaperPreset.allCases) { wp in
                        let isSelected = store.wallpaperPreset == wp
                        Button {
                            if wp == .customPhoto && store.customWallpaperPath == nil {
                                store.chooseCustomWallpaperFromFiles()
                            } else {
                                store.wallpaperPreset = wp
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    ConversationWallpaper(
                                        preset: wp,
                                        customPhotoPath: store.customWallpaperPath,
                                        blurRadius: 0,
                                        dimming: 0.08,
                                        showPattern: true,
                                        palette: palette
                                    )
                                    .frame(height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                                    if wp == .customPhoto && store.customWallpaperPath == nil {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                            .padding(6)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(wp.rawValue)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                        .foregroundColor(palette.onSurface)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(wp.subtitle)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? palette.primary.opacity(0.14) : palette.surfaceContainer)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isSelected ? palette.primary : palette.outlineVariant.opacity(0.28), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Upload Custom Wallpaper from Files / Photos
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16))
                        .foregroundColor(palette.primary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom photo wallpaper")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.onSurface)
                        if let path = store.customWallpaperPath {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundColor(palette.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Choose any JPEG, PNG, HEIC, or WebP image from your Mac.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if store.customWallpaperPath != nil {
                        Button("Remove") {
                            store.clearCustomWallpaper()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("Choose Photo...") {
                        store.chooseCustomWallpaperFromFiles()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
                }

                Divider()

                // Blur, Dimming & Pattern Controls
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Wallpaper blur: \(Int(store.wallpaperBlurRadius))pt")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Text("Dimming: \(Int((store.wallpaperDimming * 100).rounded()))%")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        Slider(value: $store.wallpaperBlurRadius, in: 0...24, step: 1)
                            .tint(palette.primary)
                        Slider(value: $store.wallpaperDimming, in: 0...0.75, step: 0.05)
                            .tint(palette.primary)
                    }
                }

                if store.wallpaperPreset != .customPhoto {
                    Divider()
                    toggleRow(
                        "Telegram motif pattern",
                        subtitle: "Overlay subtle vector chat, star, and paperplane motifs over the wallpaper.",
                        isOn: $store.showWallpaperPattern
                    )
                }
            }

            settingsCard(title: "Message Bubbles and Layout") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bubble corner radius")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(store.bubbleCornerRadius))pt")
                            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                            .foregroundColor(palette.primary)
                    }
                    Slider(value: $store.bubbleCornerRadius, in: 4...28, step: 2)
                        .tint(palette.primary)
                }

                Divider()

                toggleRow("Compact chat list", subtitle: "Use smaller rows and avatars in the chat list.", isOn: $store.compactMode)
            }

            settingsCard(title: "Messages and Emoji") {
                toggleRow("Send with Enter", subtitle: "Press Enter to send, or Shift+Enter for a new line.", isOn: $store.sendWithEnter)
                Divider()
                toggleRow("Large emoji", subtitle: "Display single-emoji messages at a larger size.", isOn: $store.largeEmoji)
                Divider()
                toggleRow("Loop animated stickers", subtitle: "Keep animated stickers playing in chats.", isOn: $store.loopAnimatedStickers)
                Divider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sticker sets")
                            .font(.system(size: 13, weight: .medium))
                        Text("Manage installed packs, view sticker counts, and copy author IDs.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Manage stickers") {
                        presentAfterClosingSettings {
                            store.showStickerManagerSheet = true
                            Task { await store.loadInstalledStickerSets() }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Divider()
                toggleRow("Show 18+ content", subtitle: "Display media marked as sensitive content.", isOn: $store.showSensitiveContent)
            }
        }
    }

    // MARK: - 5. Chat Folders
    private var chatFoldersSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Active Folders") {
                if store.folders.isEmpty {
                    Text("No folders yet. Your Telegram chat folders will appear here once synced.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.folders) { folder in
                        HStack(spacing: 12) {
                            Image(systemName: folder.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(palette.primary)
                                .frame(width: 24)
                            Text(folder.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if store.selectedFolderId == folder.id {
                                Text("Selected")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(palette.primary)
                            }
                            if folder.id != "all" {
                                Button("Delete") {
                                    Task { await store.deleteChatFolder(folder) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        if folder.id != store.folders.last?.id {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Create New Folder") {
                HStack(spacing: 10) {
                    TextField("Folder name (e.g. Work, News, Bots)", text: $store.newFolderName)
                        .textFieldStyle(.roundedBorder)
                    Button("Create Folder") {
                        Task { await store.createNewChatFolder() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
                    .disabled(store.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    Toggle("Contacts", isOn: $store.newFolderIncludeContacts)
                    Toggle("Non-Contacts", isOn: $store.newFolderIncludeNonContacts)
                    Toggle("Groups", isOn: $store.newFolderIncludeGroups)
                    Toggle("Channels", isOn: $store.newFolderIncludeChannels)
                    Toggle("Bots", isOn: $store.newFolderIncludeBots)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                if let msg = store.folderStatusMessage {
                    Text(msg)
                        .font(.system(size: 11.5))
                        .foregroundColor(palette.primary)
                }
            }
        }
    }

    // MARK: - 6. Advanced (Includes Materialgram 3-Toggle Section, Proxy, Storage & Updates)
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Data, Storage and Network") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection type")
                            .font(.system(size: 13, weight: .medium))
                        Text(store.isProxyEnabled ? "Connected through an active proxy." : "Default (TCP).")
                            .font(.system(size: 11))
                            .foregroundColor(store.isProxyEnabled ? .green : .secondary)
                    }
                    Spacer()
                    Button("Manage proxies") {
                        presentAfterClosingSettings {
                            store.showProxySheet = true
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local TDLib media cache & database")
                            .font(.system(size: 13, weight: .medium))
                        Text("Cached media: \(store.storageStats.formattedFilesSize) (\(store.storageStats.fileCount) files) • Database: \(store.storageStats.formattedDatabaseSize)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(store.isOptimizingStorage ? "Optimizing..." : "Optimize Storage") {
                        Task { await store.clearAndOptimizeStorage() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isOptimizingStorage)
                }
            }
            .onAppear {
                Task { await store.refreshStorageStats() }
            }

            // Observed in Windows materialgram.exe Advanced -> materialgram (BuildMaterialgramSection)
            settingsCard(title: AethergramBrand.appName) {
                toggleRow("Registration date", subtitle: "Show estimated account registration dates on user profiles.", isOn: $store.showRegistrationDate)
                Divider()
                toggleRow("DC", subtitle: "Show Telegram datacenter IDs on user and chat profiles.", isOn: $store.showDatacenterId)
                Divider()
                toggleRow("Profile photos", subtitle: "Use photos from @gamee in profile photo list (experimental).", isOn: $store.showMaterialgramProfilePhotos)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Telegram data")
                            .font(.system(size: 13, weight: .medium))
                        Text(store.lastExportStatus ?? "Export up to 10,000 messages to HTML and/or JSON with cached media.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Export...") {
                        presentAfterClosingSettings {
                            store.showExportSheet = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.selectedChat == nil)
                }
            }

            settingsCard(title: "Performance and Spell Checker") {
                toggleRow("Hardware accelerated video decoding", subtitle: "Use Apple Silicon VideoToolbox for smoother media playback.", isOn: $store.hardwareVideoDecoding)
                Divider()
                toggleRow("Use system spell checker", subtitle: "Check spelling using macOS system dictionaries.", isOn: $store.useSystemSpellChecker)
            }

            settingsCard(title: "Version and Updates") {
                toggleRow("Update automatically", subtitle: "Check the \(AethergramUpdateService.githubOwner)/\(AethergramUpdateService.githubRepo) GitHub release feed in the background.", isOn: $store.updateAutomatically)
                Divider()
                toggleRow("Install beta versions", subtitle: "Include pre-release builds from GitHub Releases.", isOn: $store.installBetaVersions)
                Divider()

                HStack {
                    HStack(spacing: 10) {
                        AethergramLogoView(size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(AethergramBrand.appName) v\(AethergramUpdateService.currentVersion)")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Repo: github.com/\(AethergramUpdateService.githubOwner)/\(AethergramUpdateService.githubRepo)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await store.checkUpdates()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if store.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(store.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(palette.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(palette.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isCheckingForUpdates)
                }

                if let info = store.updateInfo {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: info.hasUpdate ? "arrow.down.circle.fill" : "checkmark.shield.fill")
                                .foregroundColor(info.hasUpdate ? palette.primary : .green)
                            Text(info.hasUpdate
                                 ? "New release available: v\(info.latestVersion)"
                                 : "Up to date — latest GitHub release is v\(info.latestVersion)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(palette.onSurface)
                            Spacer()
                            if let pageURL = info.releasePageURL {
                                Link("View on GitHub", destination: pageURL)
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                        }

                        if !info.releaseNotes.isEmpty {
                            Text(info.releaseNotes)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .lineLimit(5)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(palette.surfaceContainerLow)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        HStack(spacing: 10) {
                            if info.hasUpdate && info.assetFileName != nil {
                                Button {
                                    Task { await store.downloadAndStageUpdate() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if store.isDownloadingUpdate {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.down.doc.fill")
                                        }
                                        Text(store.isDownloadingUpdate ? "Downloading..." : "Download & Verify Release")
                                    }
                                    .font(.system(size: 11.5, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(palette.primary)
                                .disabled(store.isDownloadingUpdate)
                            }

                            if let staged = store.stagedUpdateFileURL {
                                Text("Staged: \(staged.lastPathComponent)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }

                        if let err = store.updateErrorMessage {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - 7. Speakers and Camera
    private var speakersAndCameraSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Speakers and Microphone") {
                HStack {
                    Text("Output device")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("Output device", selection: $store.outputDevice) {
                        ForEach(store.availableOutputDevices, id: \.self) { device in
                            Text(device).tag(device)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                Divider()
                HStack {
                    Text("Input device")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("Input device", selection: $store.inputDevice) {
                        ForEach(store.availableInputDevices, id: \.self) { device in
                            Text(device).tag(device)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            settingsCard(title: "Calls") {
                toggleRow("Accept calls on this device", subtitle: "Allow incoming Telegram voice and video calls on this Mac.", isOn: $store.acceptCallsOnThisDevice)
            }
        }
    }

    // MARK: - 8. Battery and Animations
    private var batteryAndAnimationsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Power Saving Options") {
                toggleRow("Animated stickers", subtitle: "Autoplay animated stickers in panels and chats.", isOn: $store.autoplayAnimatedStickers)
                Divider()
                toggleRow("Animated emoji", subtitle: "Autoplay animated emoji in reactions, messages, and status.", isOn: $store.autoplayAnimatedEmoji)
                Divider()
                toggleRow("Animations in chats", subtitle: "Run wallpaper rotation, spoiler effects, and message animations.", isOn: $store.animationsInChats)
                Divider()
                toggleRow("Interface animations", subtitle: "Enable Material Design 3 transitions and ripples.", isOn: $store.interfaceAnimations)
            }
        }
    }

    // MARK: - 9. Language
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Translation") {
                toggleRow("Show translate button", subtitle: "Add a Translate action to the context menu of text messages.", isOn: $store.showTranslateButton)
                Divider()
                toggleRow("Translate entire chats", subtitle: "Show a bar at the top of chats to translate full conversations.", isOn: $store.translateEntireChats)
            }

            settingsCard(title: "Interface Language") {
                ForEach(supportedLanguages, id: \.self) { lang in
                    Button {
                        store.appLanguage = lang
                    } label: {
                        HStack {
                            Text(lang)
                                .font(.system(size: 13, weight: store.appLanguage == lang ? .semibold : .regular))
                                .foregroundColor(palette.onSurface)
                            Spacer()
                            if store.appLanguage == lang {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(palette.primary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if lang != supportedLanguages.last {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Shared MD3 Card & Toggle Helpers
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(palette.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(palette.primary)
        }
    }

    private func presentAfterClosingSettings(_ openAction: @escaping @MainActor () -> Void) {
        store.showSettingsSheet = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            openAction()
        }
    }
}
