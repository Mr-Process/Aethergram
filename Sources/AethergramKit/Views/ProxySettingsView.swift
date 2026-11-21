import SwiftUI

public struct ProxySettingsView: View {
    @ObservedObject public var store: ChatStore
    public let palette: MD3ColorPalette

    public init(store: ChatStore, palette: MD3ColorPalette) {
        self.store = store
        self.palette = palette
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 22))
                        .foregroundColor(palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection and Proxy")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(palette.onSurface)
                        Text("Configure MTProto, SOCKS5, or HTTP proxies through TDLib.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") {
                        store.showProxySheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)
                    .controlSize(.small)
                }

                // Global Proxy Toggle
                Toggle(isOn: Binding(
                    get: { store.isProxyEnabled },
                    set: { enabled in
                        if enabled, let first = store.proxies.first {
                            store.toggleProxy(first.id)
                        } else {
                            store.disableProxy()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use proxy")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text("Route Telegram traffic through the selected proxy.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(palette.primary)
                .disabled(store.proxies.isEmpty)
                .padding(14)
                .background(palette.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Add Proxy Form (Matches Windows Add Proxy: MTProto / SOCKS5 / HTTP)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Proxy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("Type", selection: $store.newProxyType) {
                        ForEach(ProxyType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        TextField("Hostname or IP", text: $store.newProxyServer)
                            .textFieldStyle(.roundedBorder)
                        TextField("Port", text: $store.newProxyPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    if store.newProxyType == .mtproto {
                        TextField("Secret", text: $store.newProxySecret)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        HStack(spacing: 10) {
                            TextField("Username (optional)", text: $store.newProxyUsername)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Password (optional)", text: $store.newProxyPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Add proxy") {
                            Task { await store.addNewProxy() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                        .disabled(store.newProxyServer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(14)
                .background(palette.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Configured Proxy List
                VStack(alignment: .leading, spacing: 10) {
                    Text("Configured Proxies")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    if store.proxies.isEmpty {
                        Text("No proxies configured. Add a proxy above to route traffic through TDLib.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(store.proxies) { proxy in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(proxy.isEnabled && store.isProxyEnabled ? Color.green : palette.outlineVariant)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(proxy.type.rawValue)
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(palette.primary.opacity(0.12))
                                            .clipShape(Capsule())
                                            .foregroundColor(palette.primary)

                                        Text("\(proxy.server):\(proxy.port)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(palette.onSurface)
                                    }

                                    if let ping = proxy.pingMs {
                                        Text("\(ping) ms - Online")
                                            .font(.system(size: 11))
                                            .foregroundColor(.green)
                                    }
                                }

                                Spacer()

                                Button(action: {
                                    store.toggleProxy(proxy.id)
                                }) {
                                    Text(proxy.isEnabled && store.isProxyEnabled ? "Active" : "Use")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(proxy.isEnabled && store.isProxyEnabled ? palette.onPrimary : palette.onSurface)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(proxy.isEnabled && store.isProxyEnabled ? palette.primary : palette.surfaceContainer)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(palette.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 460)
        .background(palette.surface)
    }
}
