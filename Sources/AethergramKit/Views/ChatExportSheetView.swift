import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
public final class ChatExportController: ObservableObject {
    @Published public var format: ChatExportFormat = .html
    @Published public var maxMessages: Int = 10_000
    @Published public var includePhotos: Bool = true
    @Published public var includeVideos: Bool = true
    @Published public var includeVoiceMessages: Bool = true
    @Published public var includeVideoMessages: Bool = true
    @Published public var includeStickers: Bool = false
    @Published public var includeAnimations: Bool = true
    @Published public var includeDocuments: Bool = true
    @Published public var destinationDirectory: URL = ChatExportOptions.defaultDestinationDirectory()
    @Published public var isExporting: Bool = false
    @Published public var statusText: String = "Choose format, message limit, and media types to export."
    @Published public var lastResult: ChatExportResult? = nil
    @Published public var errorMessage: String? = nil

    public init() {}

    public func makeOptions() -> ChatExportOptions {
        ChatExportOptions(
            format: format,
            maxMessages: maxMessages,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            includeVoiceMessages: includeVoiceMessages,
            includeVideoMessages: includeVideoMessages,
            includeStickers: includeStickers,
            includeAnimations: includeAnimations,
            includeDocuments: includeDocuments,
            destinationDirectory: destinationDirectory
        )
    }

    public func chooseDestinationFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationDirectory
        if panel.runModal() == .OK, let url = panel.url {
            destinationDirectory = url
        }
        #endif
    }

    public func revealLastExportInFinder() {
        #if os(macOS)
        guard let result = lastResult else { return }
        let target = result.htmlURL ?? result.jsonURL ?? result.exportFolderURL
        NSWorkspace.shared.activateFileViewerSelecting([target])
        #endif
    }
}

/// Full Materialgram export dialog matching Telegram Desktop / Materialgram's export sheet:
/// HTML (up to 10,000 messages per file), structured JSON, media toggles, and Finder reveal.
public struct ChatExportSheetView: View {
    @ObservedObject public var store: ChatStore
    @ObservedObject public var controller: ChatExportController
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    private let messageLimitOptions = [100, 500, 1_000, 5_000, 10_000]

    public init(
        store: ChatStore,
        controller: ChatExportController,
        palette: MD3ColorPalette,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.controller = controller
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Chat Data")
                        .font(.mgFont(size: 16, weight: .bold))
                        .foregroundColor(palette.onSurface)
                    if let chat = store.selectedChat {
                        Text("\(chat.title)\(store.selectedTopic.map { " · #\($0.name)" } ?? "")")
                            .font(.mgFont(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Format")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: $controller.format) {
                        ForEach(ChatExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack {
                    Text("Message limit")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: $controller.maxMessages) {
                        ForEach(messageLimitOptions, id: \.self) { count in
                            Text("\(count) messages").tag(count)
                        }
                    }
                    .labelsHidden()
                }
            }
            .padding(12)
            .background(palette.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Media to Include (Cached Locally)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    Toggle("Photos", isOn: $controller.includePhotos)
                    Toggle("Videos", isOn: $controller.includeVideos)
                    Toggle("Voice messages", isOn: $controller.includeVoiceMessages)
                    Toggle("Video messages", isOn: $controller.includeVideoMessages)
                    Toggle("GIFs / Animations", isOn: $controller.includeAnimations)
                    Toggle("Stickers", isOn: $controller.includeStickers)
                    Toggle("Documents & Files", isOn: $controller.includeDocuments)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 12.5))
            }
            .padding(12)
            .background(palette.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destination folder")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(controller.destinationDirectory.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose...") {
                    controller.chooseDestinationFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(palette.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if controller.isExporting {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(controller.statusText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else if let err = controller.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            } else {
                Text(controller.statusText)
                    .font(.system(size: 12))
                    .foregroundColor(controller.lastResult != nil ? palette.primary : .secondary)
            }

            HStack {
                if controller.lastResult != nil {
                    Button {
                        controller.revealLastExportInFinder()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button {
                    Task { await store.runFullChatExport() }
                } label: {
                    Text(controller.isExporting ? "Exporting..." : "Export")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.primary)
                .disabled(controller.isExporting || store.selectedChat == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 500)
        .background(palette.surface)
    }
}
