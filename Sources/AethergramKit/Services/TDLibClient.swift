import Foundation
import Darwin

public enum TDLibError: Error, Sendable {
    case libraryNotFound([String])
    case missingSymbol(String)
    case invalidJSONResponse
    case notAuthenticated
}

/// Dynamic C-ABI bridge to TDLib's `libtdjson.dylib` (installed via Homebrew `tdlib`
/// or bundled alongside the executable). Uses `dlopen`/`dlsym` so SwiftPM builds cleanly
/// under CommandLineTools without requiring Xcode binary frameworks.
public final class TDLibClient: @unchecked Sendable {
    private typealias CreateClientIdFn = @convention(c) () -> Int32
    private typealias SendFn = @convention(c) (Int32, UnsafePointer<CChar>) -> Void
    private typealias ReceiveFn = @convention(c) (Double) -> UnsafePointer<CChar>?
    private typealias ExecuteFn = @convention(c) (UnsafePointer<CChar>) -> UnsafePointer<CChar>?

    private let handle: UnsafeMutableRawPointer
    private let createClientIdFn: CreateClientIdFn
    private let sendFn: SendFn
    private let receiveFn: ReceiveFn
    private let executeFn: ExecuteFn

    public let clientId: Int32
    public let libraryPath: String

    public static let defaultSearchPaths: [String] = [
        "/opt/homebrew/opt/tdlib/lib/libtdjson.dylib",
        "/usr/local/opt/tdlib/lib/libtdjson.dylib",
        Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libtdjson.dylib").path
    ]

    public init(searchPaths: [String] = TDLibClient.defaultSearchPaths) throws {
        var loadedHandle: UnsafeMutableRawPointer?
        var resolvedPath: String = ""
        for path in searchPaths {
            if let h = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                loadedHandle = h
                resolvedPath = path
                break
            }
        }
        guard let h = loadedHandle else {
            throw TDLibError.libraryNotFound(searchPaths)
        }
        self.handle = h
        self.libraryPath = resolvedPath

        func loadSym<T>(_ name: String, as type: T.Type) throws -> T {
            guard let ptr = dlsym(h, name) else {
                throw TDLibError.missingSymbol(name)
            }
            return unsafeBitCast(ptr, to: type)
        }

        self.createClientIdFn = try loadSym("td_create_client_id", as: CreateClientIdFn.self)
        self.sendFn = try loadSym("td_send", as: SendFn.self)
        self.receiveFn = try loadSym("td_receive", as: ReceiveFn.self)
        self.executeFn = try loadSym("td_execute", as: ExecuteFn.self)
        self.clientId = createClientIdFn()
    }

    deinit {
        dlclose(handle)
    }

    /// Executes a synchronous TDLib JSON request (e.g. `getOption`, `setLogVerbosityLevel`).
    public func execute(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TDLibError.invalidJSONResponse
        }
        let responsePtr = json.withCString { executeFn($0) }
        guard let responsePtr,
              let responseStr = String(validatingCString: responsePtr),
              let responseData = responseStr.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw TDLibError.invalidJSONResponse
        }
        return obj
    }

    /// Sends an asynchronous TDLib JSON request on this client ID.
    public func send(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TDLibError.invalidJSONResponse
        }
        json.withCString { sendFn(clientId, $0) }
    }

    /// Polls for an incoming TDLib update/response up to `timeout` seconds.
    public func receive(timeout: Double = 0.2) -> [String: Any]? {
        guard let ptr = receiveFn(timeout),
              let str = String(validatingCString: ptr),
              let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }

    /// Queries the live TDLib engine version via `td_send` + `td_receive`
    /// (`getOption("version")` is asynchronous in TDLib 1.8.x).
    public func queryVersion() throws -> String {
        try send(["@type": "getOption", "name": "version", "@extra": "ver_req"])
        for _ in 0..<20 {
            guard let msg = receive(timeout: 0.25) else { continue }
            if let extra = msg["@extra"] as? String, extra == "ver_req",
               let val = msg["value"] as? String {
                return val
            }
            if let type = msg["@type"] as? String, type == "updateOption",
               let name = msg["name"] as? String, name == "version",
               let valueObj = msg["value"] as? [String: Any],
               let val = valueObj["value"] as? String {
                return val
            }
        }
        return "unknown"
    }
}
