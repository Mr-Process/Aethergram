import SwiftUI

public struct PasscodeLockView: View {
    @ObservedObject public var passcodeManager: PasscodeManager
    public let palette: MD3ColorPalette

    public init(passcodeManager: PasscodeManager, palette: MD3ColorPalette) {
        self.passcodeManager = passcodeManager
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            palette.surface
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Brand Mark & Lock Badge
                ZStack(alignment: .bottomTrailing) {
                    AethergramLogoView(size: 76)
                    Circle()
                        .fill(palette.surfaceContainerHigh)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(palette.primary)
                        )
                        .offset(x: 4, y: 4)
                }

                VStack(spacing: 6) {
                    Text("\(AethergramBrand.appName) Locked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(palette.onSurface)
                    Text("Enter your passcode to continue.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // PIN Input Dots
                HStack(spacing: 16) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < passcodeManager.currentPinInput.count ? palette.primary : palette.outlineVariant)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.vertical, 8)
                .offset(x: passcodeManager.isError ? -10 : 0)
                .animation(passcodeManager.isError ? .spring(response: 0.15, dampingFraction: 0.2) : .default, value: passcodeManager.isError)

                // Secure Field for keyboard input
                SecureField("Enter Passcode", text: $passcodeManager.currentPinInput)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
                    .padding(10)
                    .background(palette.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .multilineTextAlignment(.center)
                    .onSubmit {
                        _ = passcodeManager.verifyCurrentInput()
                    }
                    .onChange(of: passcodeManager.currentPinInput) { _, newValue in
                        if newValue.count == 4 {
                            _ = passcodeManager.verifyCurrentInput()
                        }
                    }

                HStack(spacing: 16) {
                    Button("Unlock") {
                        _ = passcodeManager.verifyCurrentInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primary)

                    if passcodeManager.biometricEnabled {
                        Button {
                            Task {
                                _ = await passcodeManager.authenticateWithBiometrics()
                            }
                        } label: {
                            Image(systemName: "touchid")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(palette.surfaceContainerLow)
                    .md3Elevation(3)
            )
        }
    }
}
