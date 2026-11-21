import SwiftUI
import WebKit

public enum MiniAppPlatformOverride {
    public static let materialgramPlatform = "android"
    public static let androidUserAgent = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"

    /// Rewrites Telegram Mini App URLs to report `tgWebAppPlatform=android`,
    /// matching Materialgram's "Replaced webview platform with android".
    public static func rewritePlatformURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "tgWebAppPlatform" }
        items.append(URLQueryItem(name: "tgWebAppPlatform", value: materialgramPlatform))
        components.queryItems = items
        return components.url ?? url
    }
}

#if os(macOS)
public struct MiniAppWebViewRepresentable: NSViewRepresentable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = MiniAppPlatformOverride.androidUserAgent
        webView.load(URLRequest(url: MiniAppPlatformOverride.rewritePlatformURL(url)))
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        let rewritten = MiniAppPlatformOverride.rewritePlatformURL(url)
        if nsView.url != rewritten {
            nsView.load(URLRequest(url: rewritten))
        }
    }
}
#endif

public struct MiniAppSheetView: View {
    public let title: String
    public let url: URL
    public let palette: MD3ColorPalette
    public let onClose: () -> Void

    public init(title: String, url: URL, palette: MD3ColorPalette, onClose: @escaping () -> Void) {
        self.title = title
        self.url = url
        self.palette = palette
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.mgFont(size: 14, weight: .bold))
                Text("platform: android")
                    .font(.mgFont(size: 10.5, weight: .semibold))
                    .foregroundColor(palette.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.primary.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
            }
            .padding(12)
            .background(palette.surfaceContainerLow)

            Divider()

            #if os(macOS)
            MiniAppWebViewRepresentable(url: url)
                .frame(minWidth: 420, minHeight: 560)
            #endif
        }
    }
}
