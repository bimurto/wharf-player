import SwiftUI

/// Shown in the player area until something is playing.
struct WelcomeView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 64, weight: .light)).foregroundStyle(Theme.gold)
            Text("Wharf").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.gold)
            Text("Play videos straight from your SFTP servers.").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(AppModel.SidebarPanel.allCases, id: \.self) { panel in
                    Button(panel.rawValue) { model.toggleSidebar(panel) }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                Button("Open URL…") { model.showOpenSheet = true }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            Text(model.servers.isEmpty ? "Start by adding a server." : "Pick a server, then a video.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
