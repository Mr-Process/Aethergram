import Foundation

public struct UserAccount: Identifiable, Hashable, Sendable {
    public let id: String
    public var firstName: String
    public var lastName: String
    public var name: String
    public var username: String
    public var phoneNumber: String
    public var bio: String
    public let avatarInitials: String
    public let avatarHue: Double
    public var avatarFileId: Int32?
    public var avatarLocalPath: String?
    public var profilePhotoId: Int64?
    public var birthDay: Int?
    public var birthMonth: Int?
    public var birthYear: Int?
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        firstName: String = "",
        lastName: String = "",
        name: String,
        username: String,
        phoneNumber: String,
        bio: String = "",
        avatarInitials: String,
        avatarHue: Double = 0.5,
        avatarFileId: Int32? = nil,
        avatarLocalPath: String? = nil,
        profilePhotoId: Int64? = nil,
        birthDay: Int? = nil,
        birthMonth: Int? = nil,
        birthYear: Int? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.firstName = firstName.isEmpty ? name : firstName
        self.lastName = lastName
        self.name = name
        self.username = username
        self.phoneNumber = phoneNumber
        self.bio = bio
        self.avatarInitials = avatarInitials
        self.avatarHue = avatarHue
        self.avatarFileId = avatarFileId
        self.avatarLocalPath = avatarLocalPath
        self.profilePhotoId = profilePhotoId
        self.birthDay = birthDay
        self.birthMonth = birthMonth
        self.birthYear = birthYear
        self.isActive = isActive
    }
}

public struct ActiveTelegramSession: Identifiable, Hashable, Sendable {
    public let id: Int64
    public let applicationName: String
    public let applicationVersion: String
    public let deviceModel: String
    public let platform: String
    public let systemVersion: String
    public let ipAddress: String
    public let location: String
    public let isCurrent: Bool

    public init(
        id: Int64,
        applicationName: String,
        applicationVersion: String,
        deviceModel: String,
        platform: String,
        systemVersion: String,
        ipAddress: String,
        location: String,
        isCurrent: Bool
    ) {
        self.id = id
        self.applicationName = applicationName
        self.applicationVersion = applicationVersion
        self.deviceModel = deviceModel
        self.platform = platform
        self.systemVersion = systemVersion
        self.ipAddress = ipAddress
        self.location = location
        self.isCurrent = isCurrent
    }
}

public struct TDLibStorageStats: Equatable, Sendable {
    public let filesSizeBytes: Int64
    public let fileCount: Int
    public let databaseSizeBytes: Int64

    public init(filesSizeBytes: Int64 = 0, fileCount: Int = 0, databaseSizeBytes: Int64 = 0) {
        self.filesSizeBytes = filesSizeBytes
        self.fileCount = fileCount
        self.databaseSizeBytes = databaseSizeBytes
    }

    public var formattedFilesSize: String {
        ByteCountFormatter.string(fromByteCount: filesSizeBytes, countStyle: .file)
    }

    public var formattedDatabaseSize: String {
        ByteCountFormatter.string(fromByteCount: databaseSizeBytes, countStyle: .file)
    }
}
