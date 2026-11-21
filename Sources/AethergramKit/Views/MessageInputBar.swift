import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct MessageInputBar: View {
    @Binding public var text: String
    public let replyingTo: Message?
    public let palette: MD3ColorPalette
    public let onDismissReply: () -> Void
    public let onAttach: () -> Void
    public let onSend: () -> Void

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        text: Binding<String>,
        replyingTo: Message? = nil,
        palette: MD3ColorPalette,
        onDismissReply: @escaping () -> Void,
        onAttach: @escaping () -> Void = {},
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self.replyingTo = replyingTo
        self.palette = palette
        self.onDismissReply = onDismissReply
        self.onAttach = onAttach
        self.onSend = onSend
    }

    public var body: some View {
        VStack(spacing: 8) {
            if let reply = replyingTo {
                ReplyPreviewBanner(
                    reply: reply,
                    palette: palette,
                    onDismiss: onDismissReply
                )
            }

            LiquidGlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: onAttach) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(palette.onSurface.opacity(0.78))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help("Attach photo or file")

                    TextField("Write a message...", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit(onSend)

                    Button(action: openEmojiPicker) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(palette.onSurface.opacity(0.78))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help("Emoji and Symbols")

                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isSendDisabled ? .secondary : palette.onPrimary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isSendDisabled ? palette.surfaceContainerHigh.opacity(0.6) : palette.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendDisabled)
                    .animation(.easeInOut(duration: 0.15), value: isSendDisabled)
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 7)
                .mgGlassCapsule(
                    tint: palette.surfaceContainer.opacity(0.32),
                    interactive: true
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func openEmojiPicker() {
        #if os(macOS)
        NSApp.orderFrontCharacterPalette(nil)
        #endif
    }
}

private struct ReplyPreviewBanner: View {
    let reply: Message
    let palette: MD3ColorPalette
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.primary)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(reply.senderName)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(palette.primary)
                Text(reply.text.isEmpty ? "Media attachment" : reply.text)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .mgGlassCard(
            cornerRadius: 14,
            tint: palette.surfaceContainerHigh.opacity(0.45)
        )
    }
}
