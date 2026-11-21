import Foundation
import LocalAuthentication

@MainActor
public final class PasscodeManager: ObservableObject {
    @Published public var isPasscodeEnabled: Bool = false
    @Published public var isLocked: Bool = false
    @Published public var autoLockIntervalSeconds: Int = 300 // 5 minutes default
    @Published public var biometricEnabled: Bool = true
    @Published public var lastUnlockDate: Date = Date()

    @Published public var currentPinInput: String = ""
    @Published public var isError: Bool = false

    private var storedPasscodeHash: String? = nil

    public init() {}

    public func setPasscode(_ pin: String) {
        if pin.isEmpty {
            storedPasscodeHash = nil
            isPasscodeEnabled = false
            isLocked = false
        } else {
            storedPasscodeHash = hashPasscode(pin)
            isPasscodeEnabled = true
        }
    }

    public func verifyCurrentInput() -> Bool {
        guard let hash = storedPasscodeHash else {
            isLocked = false
            currentPinInput = ""
            return true
        }
        let matches = (hash == hashPasscode(currentPinInput))
        if matches {
            isLocked = false
            isError = false
            currentPinInput = ""
            lastUnlockDate = Date()
            return true
        } else {
            isError = true
            currentPinInput = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isError = false
            }
            return false
        }
    }

    public func lockNow() {
        if isPasscodeEnabled {
            isLocked = true
            currentPinInput = ""
            isError = false
        }
    }

    public func authenticateWithBiometrics() async -> Bool {
        guard isPasscodeEnabled && biometricEnabled else { return false }
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Unlock \(AethergramBrand.appName)"
                )
                if success {
                    isLocked = false
                    lastUnlockDate = Date()
                    return true
                }
            } catch {
                return false
            }
        }
        return false
    }

    private func hashPasscode(_ pin: String) -> String {
        var hash: UInt64 = 5381
        for byte in pin.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }
}
