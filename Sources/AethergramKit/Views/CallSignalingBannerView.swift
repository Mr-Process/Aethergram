import SwiftUI

public enum CallSignalingState: Equatable, Sendable {
    case idle
    case outgoing(callId: Int32, peerTitle: String)
    case incoming(callId: Int32, peerTitle: String)
    case activeSignaling(callId: Int32, peerTitle: String)
    case ended(reason: String)
}

/// Phase 5 (Option A) TDLib Call Signaling Banner.
/// Drives real TDLib `createCall`, `acceptCall`, and `discardCall` signaling while keeping
/// WebRTC (`tgcalls`) media transport modular for Phase 5B.
public struct CallSignalingBannerView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette

    public init(store: ChatStore, palette: MD3ColorPalette) {
        self.store = store
        self.palette = palette
    }

    public var body: some View {
        switch store.callState {
        case .idle:
            EmptyView()
        case .outgoing(let callId, let peerTitle):
            banner(title: "Calling \(peerTitle)...", subtitle: "TDLib signaling active (call #\(callId))", showAccept: false, callId: callId)
        case .incoming(let callId, let peerTitle):
            banner(title: "Incoming call from \(peerTitle)", subtitle: "TDLib call signaling (WebRTC media pending Phase 5B)", showAccept: true, callId: callId)
        case .activeSignaling(let callId, let peerTitle):
            banner(title: "Call signaling connected: \(peerTitle)", subtitle: "Call #\(callId) • WebRTC media bridge pending Phase 5B", showAccept: false, callId: callId)
        case .ended(let reason):
            HStack {
                Text("Call ended: \(reason)")
                    .font(.mgFont(size: 12))
                Spacer()
                Button("Dismiss") { store.callState = .idle }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(palette.surfaceContainerHigh)
        }
    }

    private func banner(title: String, subtitle: String, showAccept: Bool, callId: Int32) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mgFont(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.mgFont(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if showAccept {
                Button("Accept") {
                    Task { await store.acceptActiveCall(callId: callId) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            }
            Button("Hang up") {
                Task { await store.discardActiveCall(callId: callId) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.surfaceContainerHigh)
    }
}
