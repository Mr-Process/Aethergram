import Foundation
import CryptoKit

public struct UpdateInfo: Sendable {
    public let latestVersion: String
    public let currentVersion: String
    public let hasUpdate: Bool
    public let isPrerelease: Bool
    public let releaseNotes: String
    public let releasePageURL: URL?
    public let downloadUrl: URL?
    public let assetFileName: String?
    public let expectedSHA256: String?
    public let publishedAt: String?
    public let sourceEndpoint: String

    public init(
        latestVersion: String,
        currentVersion: String,
        hasUpdate: Bool,
        isPrerelease: Bool = false,
        releaseNotes: String,
        releasePageURL: URL? = nil,
        downloadUrl: URL? = nil,
        assetFileName: String? = nil,
        expectedSHA256: String? = nil,
        publishedAt: String? = nil,
        sourceEndpoint: String = AethergramUpdateService.githubReleasesLatestAPI
    ) {
        self.latestVersion = latestVersion
        self.currentVersion = currentVersion
        self.hasUpdate = hasUpdate
        self.isPrerelease = isPrerelease
        self.releaseNotes = releaseNotes
        self.releasePageURL = releasePageURL
        self.downloadUrl = downloadUrl
        self.assetFileName = assetFileName
        self.expectedSHA256 = expectedSHA256
        self.publishedAt = publishedAt
        self.sourceEndpoint = sourceEndpoint
    }
}

public enum UpdateStagingError: Error, Equatable, Sendable {
    case digestMismatch(expected: String, actual: String)
    case forbiddenPayloadName(String)
    case missingDownloadURL
    case networkFailure(String)
}

public actor AethergramUpdateService {
    public static let currentVersion = AethergramBrand.version
    public static let githubOwner = "Mr-Process"
    public static let githubRepo = "Aethergram"

    /// Primary GitHub Releases endpoints for `Mr-Process/Aethergram`
    public static let githubRepositoryURL = "https://github.com/\(githubOwner)/\(githubRepo)"
    public static let githubReleaseURL = "https://github.com/\(githubOwner)/\(githubRepo)/releases"
    public static let githubReleasesLatestAPI = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
    public static let githubReleasesListAPI = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases?per_page=10"
    public static let updateManifestURL = "https://raw.githubusercontent.com/\(githubOwner)/\(githubRepo)/main/updates/current.json"

    /// Retained for upstream parity reference tests
    public static let updateFeedURL = githubReleaseURL
    public static let currentManifestEndpoint = githubReleasesLatestAPI

    public init() {}

    /// Performs a live HTTPS query against the `Mr-Process/Aethergram` GitHub Releases API
    /// (or `/releases?per_page=10` when `includePrereleases` is enabled), falling back to
    /// `updates/current.json` in the repository if no release is returned.
    public func checkForUpdates(includePrereleases: Bool = false) async -> UpdateInfo {
        // 1. Try GitHub Releases API (live call to api.github.com/repos/Mr-Process/Aethergram/releases)
        if let releaseInfo = try? await fetchFromGitHubReleasesAPI(includePrereleases: includePrereleases) {
            return releaseInfo
        }

        // 2. Fallback to raw repository update manifest (updates/current.json on main)
        if let manifestInfo = try? await fetchFromRepositoryManifest() {
            return manifestInfo
        }

        // 3. Offline / unreachable fallback reporting the current build state
        return UpdateInfo(
            latestVersion: Self.currentVersion,
            currentVersion: Self.currentVersion,
            hasUpdate: false,
            isPrerelease: false,
            releaseNotes: "Could not reach \(Self.githubRepositoryURL). Running Aethergram v\(Self.currentVersion).",
            releasePageURL: URL(string: Self.githubReleaseURL),
            downloadUrl: URL(string: Self.githubReleaseURL),
            sourceEndpoint: Self.githubReleasesLatestAPI
        )
    }

    private func fetchFromGitHubReleasesAPI(includePrereleases: Bool) async throws -> UpdateInfo {
        let endpoint = includePrereleases ? Self.githubReleasesListAPI : Self.githubReleasesLatestAPI
        guard let url = URL(string: endpoint) else {
            throw UpdateStagingError.networkFailure("Invalid GitHub API URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Aethergram/\(Self.currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateStagingError.networkFailure("GitHub API returned non-200 status")
        }

        let releaseDict: [String: Any]
        if includePrereleases {
            guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = list.first(where: { ($0["draft"] as? Bool) != true }) else {
                throw UpdateStagingError.networkFailure("No published releases in list")
            }
            releaseDict = first
        } else {
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UpdateStagingError.networkFailure("Invalid release JSON object")
            }
            releaseDict = obj
        }

        return parseGitHubReleaseJSON(releaseDict, endpoint: endpoint)
    }

    private func fetchFromRepositoryManifest() async throws -> UpdateInfo {
        guard let url = URL(string: Self.updateManifestURL) else {
            throw UpdateStagingError.networkFailure("Invalid manifest URL")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Aethergram/\(Self.currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateStagingError.networkFailure("Manifest unavailable")
        }

        let rawTag = (dict["version"] as? String) ?? (dict["tag_name"] as? String) ?? Self.currentVersion
        let latest = Self.normalizeVersion(rawTag)
        let notes = (dict["release_notes"] as? String) ?? (dict["body"] as? String) ?? "Aethergram v\(latest)"
        let downloadStr = (dict["download_url"] as? String) ?? Self.githubReleaseURL
        let sha256 = dict["sha256"] as? String
        let fileName = (dict["asset_name"] as? String) ?? "Aethergram-macOS-arm64.zip"
        let hasNewer = Self.isVersion(latest, newerThan: Self.currentVersion)

        return UpdateInfo(
            latestVersion: latest,
            currentVersion: Self.currentVersion,
            hasUpdate: hasNewer,
            isPrerelease: (dict["prerelease"] as? Bool) ?? false,
            releaseNotes: notes,
            releasePageURL: URL(string: Self.githubReleaseURL),
            downloadUrl: URL(string: downloadStr),
            assetFileName: fileName,
            expectedSHA256: sha256,
            publishedAt: dict["published_at"] as? String,
            sourceEndpoint: Self.updateManifestURL
        )
    }

    public func parseGitHubReleaseJSON(_ releaseDict: [String: Any], endpoint: String = githubReleasesLatestAPI) -> UpdateInfo {
        let rawTag = (releaseDict["tag_name"] as? String)
            ?? (releaseDict["name"] as? String)
            ?? Self.currentVersion
        let latestVersion = Self.normalizeVersion(rawTag)
        let isPrerelease = (releaseDict["prerelease"] as? Bool) ?? false
        let body = (releaseDict["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let htmlURLString = (releaseDict["html_url"] as? String) ?? Self.githubReleaseURL
        let publishedAt = releaseDict["published_at"] as? String

        var chosenDownloadURL: URL? = URL(string: htmlURLString)
        var chosenAssetName: String? = nil
        var extractedSHA256: String? = Self.extractSHA256(fromText: body)

        if let assets = releaseDict["assets"] as? [[String: Any]] {
            // Prefer macOS .zip or .dmg bundle asset
            if let macAsset = assets.first(where: { asset in
                let name = ((asset["name"] as? String) ?? "").lowercased()
                return name.hasSuffix(".zip") || name.hasSuffix(".dmg") || name.hasSuffix(".tar.gz")
            }) ?? assets.first {
                chosenAssetName = macAsset["name"] as? String
                if let dl = macAsset["browser_download_url"] as? String, let url = URL(string: dl) {
                    chosenDownloadURL = url
                }
                if let digest = macAsset["digest"] as? String,
                   digest.lowercased().hasPrefix("sha256:") {
                    extractedSHA256 = String(digest.dropFirst("sha256:".count))
                }
            }
        }

        let hasUpdate = Self.isVersion(latestVersion, newerThan: Self.currentVersion)
        let notes = body.isEmpty ? "Aethergram v\(latestVersion) published on GitHub." : body

        return UpdateInfo(
            latestVersion: latestVersion,
            currentVersion: Self.currentVersion,
            hasUpdate: hasUpdate,
            isPrerelease: isPrerelease,
            releaseNotes: notes,
            releasePageURL: URL(string: htmlURLString),
            downloadUrl: chosenDownloadURL,
            assetFileName: chosenAssetName,
            expectedSHA256: extractedSHA256,
            publishedAt: publishedAt,
            sourceEndpoint: endpoint
        )
    }

    /// Downloads the release asset from GitHub and stages it into `<stagingDirectory>/tupdates/ready/<fileName>`,
    /// verifying its SHA-256 digest if an expected digest was published in the release notes or GitHub asset metadata.
    public func downloadAndStageRelease(
        _ info: UpdateInfo,
        stagingDirectory: URL = TDLibConfiguration.defaultSupportDirectory()
    ) async throws -> URL {
        guard let downloadURL = info.downloadUrl else {
            throw UpdateStagingError.missingDownloadURL
        }
        var request = URLRequest(url: downloadURL)
        request.timeoutInterval = 60
        request.setValue("Aethergram/\(Self.currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateStagingError.networkFailure("Could not download release asset from \(downloadURL.absoluteString)")
        }

        let fileName = info.assetFileName ?? "Aethergram-v\(info.latestVersion)-macOS.zip"
        let expectedHash = info.expectedSHA256 ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return try stageUpdatePayload(
            fileName: fileName,
            data: data,
            expectedSHA256: expectedHash,
            stagingDirectory: stagingDirectory
        )
    }

    /// Normalizes tags like `"v1.10.2"` or `"Aethergram-v1.10"` into `"1.10.2"`.
    public static func normalizeVersion(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = cleaned.range(of: #"[0-9]+(\.[0-9]+)+"#, options: .regularExpression) {
            cleaned = String(cleaned[range])
        } else if cleaned.lowercased().hasPrefix("v") {
            cleaned = String(cleaned.dropFirst())
        }
        return cleaned
    }

    /// Numeric semantic version comparison (`1.11` > `1.10` > `1.9.5`).
    public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = normalizeVersion(candidate).split(separator: ".").compactMap { Int($0) }
        let rhs = normalizeVersion(current).split(separator: ".").compactMap { Int($0) }
        let maxCount = max(lhs.count, rhs.count)
        for i in 0..<maxCount {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r {
                return l > r
            }
        }
        return false
    }

    /// Extracts a 64-character SHA-256 hex digest from release notes (`SHA256: <64-hex>`).
    public static func extractSHA256(fromText text: String) -> String? {
        guard let range = text.range(of: #"\b[a-fA-F0-9]{64}\b"#, options: .regularExpression) else {
            return nil
        }
        return String(text[range]).lowercased()
    }

    /// Verifies a downloaded update payload against its expected SHA-256 hex digest,
    /// rejects forbidden nested updater binaries (mirroring Updater.exe FUN_140003964),
    /// and stages it under `<stagingDirectory>/tupdates/ready/<fileName>`.
    public func stageUpdatePayload(
        fileName: String,
        data: Data,
        expectedSHA256: String,
        stagingDirectory: URL
    ) throws -> URL {
        let lower = fileName.lowercased()
        if lower == "updater.exe" || lower.contains("..") || lower.contains("/") {
            throw UpdateStagingError.forbiddenPayloadName(fileName)
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expectedSHA256.lowercased() else {
            throw UpdateStagingError.digestMismatch(expected: expectedSHA256.lowercased(), actual: actual)
        }
        let readyDir = stagingDirectory
            .appendingPathComponent("tupdates", isDirectory: true)
            .appendingPathComponent("ready", isDirectory: true)
        try FileManager.default.createDirectory(at: readyDir, withIntermediateDirectories: true)
        let dest = readyDir.appendingPathComponent(fileName)
        try data.write(to: dest, options: .atomic)
        return dest
    }
}

public typealias MaterialgramUpdateService = AethergramUpdateService
