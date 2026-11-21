import SwiftUI
import AVKit
import AVFoundation
#if os(macOS)
import AppKit
#endif

public struct MediaViewerItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let fileId: Int32?
    public let localFileURL: URL?
    public let thumbnailPath: String?
    public let minithumbnailBase64: String?
    public let isVideo: Bool
    public let isRoundVideo: Bool
    public let isAnimation: Bool
    public let expectedFileSize: Int64
    public let datacenterId: Int?
    public let originalDate: String?
    public let platformName: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        fileId: Int32? = nil,
        localFileURL: URL? = nil,
        thumbnailPath: String? = nil,
        minithumbnailBase64: String? = nil,
        isVideo: Bool = false,
        isRoundVideo: Bool = false,
        isAnimation: Bool = false,
        expectedFileSize: Int64 = 0,
        datacenterId: Int? = nil,
        originalDate: String? = nil,
        platformName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.fileId = fileId
        self.localFileURL = localFileURL
        self.thumbnailPath = thumbnailPath
        self.minithumbnailBase64 = minithumbnailBase64
        self.isVideo = isVideo
        self.isRoundVideo = isRoundVideo
        self.isAnimation = isAnimation
        self.expectedFileSize = expectedFileSize
        self.datacenterId = datacenterId
        self.originalDate = originalDate
        self.platformName = platformName
    }
}

@MainActor
public final class MediaViewerController: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var resolvedFileURL: URL?
    @Published public var downloadProgress: Double = 0
    @Published public var downloadedBytes: Int64 = 0
    @Published public var expectedBytes: Int64 = 0
    @Published public var isDownloading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var seekSeconds: Double = 0
    @Published public var durationSeconds: Double = 60

    public let item: MediaViewerItem
    private var downloadTask: Task<Void, Never>?
    private var loopObserver: NSObjectProtocol?

    public init(item: MediaViewerItem) {
        self.item = item
        self.expectedBytes = item.expectedFileSize
        if let url = item.localFileURL, FileManager.default.fileExists(atPath: url.path) {
            self.resolvedFileURL = url
            self.downloadProgress = 1.0
            setupPlayerIfNeeded(for: url)
        }
    }

    private func setupPlayerIfNeeded(for url: URL) {
        guard item.isVideo || item.isRoundVideo || item.isAnimation else { return }
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        let avPlayer = AVPlayer(url: url)
        avPlayer.actionAtItemEnd = item.isAnimation ? .none : .pause

        if let currentItem = avPlayer.currentItem {
            if item.isAnimation {
                loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: currentItem,
                    queue: .main
                ) { [weak avPlayer] _ in
                    Task { @MainActor in
                        avPlayer?.seek(to: .zero)
                        avPlayer?.play()
                    }
                }
            }
            Task { @MainActor [weak self, weak currentItem] in
                guard let currentItem else { return }
                if let cmDuration = try? await currentItem.asset.load(.duration) {
                    let secs = CMTimeGetSeconds(cmDuration)
                    if secs.isFinite && secs > 0 {
                        self?.durationSeconds = secs
                    }
                }
            }
        }

        self.player = avPlayer
        avPlayer.play()
    }

    public func startDownloadIfNeeded(
        provider: TDLibTelegramProvider?,
        onDownloaded: (@MainActor @Sendable (String) -> Void)? = nil
    ) {
        if let url = resolvedFileURL, FileManager.default.fileExists(atPath: url.path) {
            if player == nil {
                setupPlayerIfNeeded(for: url)
            } else {
                player?.play()
            }
            return
        }

        guard let fileId = item.fileId, let provider else {
            errorMessage = "Media file is unavailable for download."
            return
        }

        downloadTask?.cancel()
        isDownloading = true
        errorMessage = nil

        downloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let initial = try await provider.startFileDownload(fileId: fileId, priority: 32)
                if Task.isCancelled { return }
                self.downloadedBytes = initial.downloadedSize
                self.expectedBytes = max(self.expectedBytes, initial.expectedSize)
                self.downloadProgress = initial.fractionCompleted

                if initial.isCompleted, let path = initial.localPath {
                    self.completeDownload(path: path, onDownloaded: onDownloaded)
                    return
                }

                // Poll getFile every 200ms up to 3 minutes while TDLib streams chunks
                for _ in 0..<900 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if Task.isCancelled { return }
                    let prog = try await provider.queryFileProgress(fileId: fileId)
                    if Task.isCancelled { return }

                    self.downloadedBytes = prog.downloadedSize
                    if prog.expectedSize > 0 {
                        self.expectedBytes = max(self.expectedBytes, prog.expectedSize)
                    }
                    self.downloadProgress = prog.fractionCompleted

                    if prog.isCompleted, let path = prog.localPath {
                        self.completeDownload(path: path, onDownloaded: onDownloaded)
                        return
                    }
                }

                self.isDownloading = false
                self.errorMessage = "Download timed out. Check your connection and try again."
            } catch {
                if !Task.isCancelled {
                    self.isDownloading = false
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func completeDownload(path: String, onDownloaded: (@MainActor @Sendable (String) -> Void)?) {
        let url = URL(fileURLWithPath: path)
        self.resolvedFileURL = url
        self.downloadProgress = 1.0
        self.isDownloading = false
        onDownloaded?(path)
        self.setupPlayerIfNeeded(for: url)
    }

    public func cancelDownload(provider: TDLibTelegramProvider?) {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        if let fid = item.fileId, let provider {
            Task { await provider.cancelFileDownload(fileId: fid) }
        }
    }

    public func seek(to seconds: Double) {
        seekSeconds = seconds
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    public func cleanup(provider: TDLibTelegramProvider? = nil) {
        downloadTask?.cancel()
        downloadTask = nil
        if isDownloading, let fid = item.fileId, let provider {
            Task { await provider.cancelFileDownload(fileId: fid) }
        }
        isDownloading = false
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    public func revealInFinder() {
        #if os(macOS)
        guard let url = resolvedFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    public func saveCopy() {
        #if os(macOS)
        guard let src = resolvedFileURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = src.lastPathComponent
        if panel.runModal() == .OK, let dst = panel.url {
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: src, to: dst)
        }
        #endif
    }

    public var formattedProgressStatus: String {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        let pct = Int((downloadProgress * 100.0).rounded())
        if expectedBytes > 0 {
            let dlStr = fmt.string(fromByteCount: downloadedBytes)
            let expStr = fmt.string(fromByteCount: expectedBytes)
            return "\(dlStr) / \(expStr) (\(pct)%)"
        } else if downloadedBytes > 0 {
            return "Downloaded \(fmt.string(fromByteCount: downloadedBytes))"
        }
        return "Starting download..."
    }
}

#if os(macOS)
/// Native AppKit `AVPlayerView` wrapper that avoids `_AVKit_SwiftUI.VideoPlayer`
/// Swift class metadata crashes under CommandLineTools builds on macOS 27.
public struct NativeAVPlayerView: NSViewRepresentable {
    public let player: AVPlayer
    public let showsControls: Bool

    public init(player: AVPlayer, showsControls: Bool = true) {
        self.player = player
        self.showsControls = showsControls
    }

    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = showsControls ? .inline : .none
        view.showsFullScreenToggleButton = showsControls
        view.videoGravity = .resizeAspect
        return view
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
#endif

/// Media viewer lightbox with non-blocking TDLib download progress, native macOS video playback,
/// looping GIF support, round-video seeking, Save/Reveal actions, and Materialgram metadata badges.
public struct MediaViewerView: View {
    public let item: MediaViewerItem
    @ObservedObject public var controller: MediaViewerController
    public let palette: MD3ColorPalette
    public let provider: TDLibTelegramProvider?
    public let isBookmarked: Bool
    public let onToggleBookmark: (() -> Void)?
    public let onDownloadedPath: (@MainActor @Sendable (String) -> Void)?
    public let onClose: () -> Void

    public init(
        item: MediaViewerItem,
        controller: MediaViewerController,
        palette: MD3ColorPalette,
        provider: TDLibTelegramProvider? = nil,
        isBookmarked: Bool = false,
        onToggleBookmark: (() -> Void)? = nil,
        onDownloadedPath: (@MainActor @Sendable (String) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.item = item
        self.controller = controller
        self.palette = palette
        self.provider = provider
        self.isBookmarked = isBookmarked
        self.onToggleBookmark = onToggleBookmark
        self.onDownloadedPath = onDownloadedPath
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.mgFont(size: 15, weight: .bold))
                    .foregroundColor(palette.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let onToggleBookmark {
                    Button(action: onToggleBookmark) {
                        Label(
                            isBookmarked ? "Bookmarked" : "Bookmark",
                            systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(isBookmarked ? palette.primary : nil)
                    .controlSize(.small)
                }

                if controller.resolvedFileURL != nil {
                    Button {
                        controller.revealInFinder()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        controller.saveCopy()
                    } label: {
                        Label("Save As...", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Done") {
                    controller.cleanup(provider: provider)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.primary)
                .controlSize(.small)
            }

            if let player = controller.player {
                #if os(macOS)
                NativeAVPlayerView(player: player, showsControls: !item.isRoundVideo && !item.isAnimation)
                    .frame(minWidth: 480, minHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: item.isRoundVideo ? 160 : 12))
                #endif

                if item.isRoundVideo {
                    HStack(spacing: 10) {
                        Text("Seek round video")
                            .font(.mgFont(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { controller.seekSeconds },
                            set: { controller.seek(to: $0) }
                        ), in: 0...max(1, controller.durationSeconds))
                        .tint(palette.primary)
                    }
                }
            } else if controller.isDownloading || controller.resolvedFileURL == nil {
                ZStack {
                    #if os(macOS)
                    if let thumb = previewThumbnailImage {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 640, maxHeight: 360)
                            .blur(radius: 3)
                            .overlay(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.surfaceContainerHigh)
                            .frame(minWidth: 480, minHeight: 320)
                    }
                    #endif

                    if let err = controller.errorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.mgFont(size: 12.5))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Button("Retry Download") {
                                controller.startDownloadIfNeeded(provider: provider, onDownloaded: onDownloadedPath)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(palette.primary)
                            .controlSize(.small)
                        }
                        .padding(18)
                        .background(Color.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 10) {
                            ProgressView(value: max(0.02, controller.downloadProgress))
                                .progressViewStyle(.linear)
                                .tint(palette.primary)
                                .frame(width: 240)

                            Text(controller.formattedProgressStatus)
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundColor(.white)

                            Button("Cancel") {
                                controller.cancelDownload(provider: provider)
                                onClose()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .frame(minWidth: 480, minHeight: 340)
            } else if let url = controller.resolvedFileURL {
                #if os(macOS)
                if let img = NSImage(contentsOf: url) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 680, maxHeight: 460)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Saved file: \(url.lastPathComponent)")
                        .font(.mgFont(size: 13))
                        .foregroundColor(.secondary)
                        .frame(minHeight: 280)
                }
                #endif
            }

            // Materialgram metadata bar (DC, original date, platform)
            HStack(spacing: 16) {
                if let dc = item.datacenterId {
                    Label("DC \(dc)", systemImage: "server.rack")
                }
                if let date = item.originalDate {
                    Label(date, systemImage: "calendar")
                }
                if let platform = item.platformName {
                    Label(platform, systemImage: "desktopcomputer")
                }
                Spacer()
            }
            .font(.mgFont(size: 11.5))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 500)
        .background(palette.surface)
        .task(id: item.id) {
            controller.startDownloadIfNeeded(provider: provider, onDownloaded: onDownloadedPath)
        }
        .onDisappear {
            controller.cleanup(provider: provider)
        }
    }

    #if os(macOS)
    private var previewThumbnailImage: NSImage? {
        if let thumb = item.thumbnailPath, !thumb.isEmpty, let img = NSImage(contentsOfFile: thumb) {
            return img
        }
        if let mini = item.minithumbnailBase64, !mini.isEmpty,
           let data = Data(base64Encoded: mini),
           let img = NSImage(data: data) {
            return img
        }
        return nil
    }
    #endif
}
