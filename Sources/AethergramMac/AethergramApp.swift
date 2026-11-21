import SwiftUI
import AethergramKit

@main
struct AethergramApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            MainSplitView(store: store)
                .frame(minWidth: 850, idealWidth: 1100, minHeight: 580, idealHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .appInfo) {
                Button("About \(AethergramBrand.appName)") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: AethergramBrand.appName,
                            .applicationVersion: AethergramBrand.version,
                            .version: "Build \(AethergramBrand.buildNumber)"
                        ]
                    )
                }
            }

            CommandMenu("Security") {
                Button("Lock \(AethergramBrand.appName)") {
                    withAnimation {
                        store.passcodeManager.lockNow()
                    }
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!store.passcodeManager.isPasscodeEnabled)
            }

            CommandGroup(after: .appSettings) {
                Button("\(AethergramBrand.appName) Settings...") {
                    store.showSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
