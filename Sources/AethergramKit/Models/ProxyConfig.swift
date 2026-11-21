import Foundation

public enum ProxyType: String, CaseIterable, Identifiable, Sendable {
    case socks5 = "SOCKS5"
    case http = "HTTP"
    case mtproto = "MTProto"

    public var id: String { rawValue }
}

public struct ProxyConfig: Identifiable, Hashable, Sendable {
    public let id: String
    public var type: ProxyType
    public var server: String
    public var port: Int
    public var username: String?
    public var password: String?
    public var secret: String? // For MTProto proxy
    public var pingMs: Int?
    public var isEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        type: ProxyType,
        server: String,
        port: Int,
        username: String? = nil,
        password: String? = nil,
        secret: String? = nil,
        pingMs: Int? = nil,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.type = type
        self.server = server
        self.port = port
        self.username = username
        self.password = password
        self.secret = secret
        self.pingMs = pingMs
        self.isEnabled = isEnabled
    }
}
