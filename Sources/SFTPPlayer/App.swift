import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)   // running unbundled via `swift run`
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { AppModel.shared.shutdown() }
}

@main
struct SFTPPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("SFTP Media Player", id: "player") {
            PlayerScreen(model: .shared).frame(minWidth: 640, minHeight: 360)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") { AppModel.shared.showOpenSheet = true }.keyboardShortcut("o")
            }
        }
    }
}
