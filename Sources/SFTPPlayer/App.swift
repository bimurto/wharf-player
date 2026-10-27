import SwiftUI
import Core

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

    /// Runs before any scene is built, so before `AppModel.shared` creates the stores that read defaults.
    init() { LegacyMigration.runAtStartup() }

    var body: some Scene {
        Window("Wharf", id: "player") {
            PlayerScreen(model: .shared).frame(minWidth: 640, minHeight: 360)
                .tint(Theme.gold).preferredColorScheme(.dark)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") { AppModel.shared.showOpenSheet = true }.keyboardShortcut("o")
            }
            CommandGroup(after: .sidebar) {
                ForEach(Array(AppModel.SidebarPanel.allCases.enumerated()), id: \.element) { index, panel in
                    Button(panel.rawValue) { AppModel.shared.toggleSidebar(panel) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
            }
        }
    }
}
