import SwiftUI
import Core

struct RecentsPanel: View {
    let model: AppModel
    @State private var confirmingClear = false
    @State private var hostKeyIssue: HostKeyIssue?
    @State private var pendingTarget: SFTPTarget?
    @State private var pendingItem: RecentItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recents").font(.headline)
                Spacer()
                Button("Clear") { confirmingClear = true }.disabled(model.recentItems.isEmpty)
            }
            .padding(12)
            Divider()
            if model.recentItems.isEmpty {
                Text("Videos you play show up here with their progress.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(24).frame(maxHeight: .infinity)
            } else {
                List(model.recentItems) { item in row(item) }
            }
            if let error = model.openError, !model.showOpenSheet {
                Text("Playback failed: \(error)").font(.callout).foregroundStyle(.red).padding(10)
            }
        }
        .confirmationDialog("Clear recents?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.clearRecents() }
        } message: {
            Text("This removes the watch history and resume positions. Your files are not touched.")
        }
        .hostKeyDialog($hostKeyIssue) { fingerprint in
            guard let target = pendingTarget, let item = pendingItem else { return }
            Task {
                if let failure = await model.trust(fingerprint, target: target) {
                    model.openError = failure.description
                } else {
                    play(item)
                }
            }
        }
    }

    private func play(_ item: RecentItem) {
        Task {
            if case .hostKey(let issue, let target) = await model.open(urlString: item.url, keyPath: model.defaultKeyPath) {
                pendingTarget = target
                pendingItem = item
                hostKeyIssue = issue
            }
        }
    }

    private func row(_ item: RecentItem) -> some View {
        Button { play(item) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).lineLimit(1).truncationMode(.middle)
                if item.duration > 0 {
                    ProgressView(value: item.fraction).progressViewStyle(.linear)
                }
                Text(detail(item)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(item.title)\n\(item.url)")
        .padding(.vertical, 3)
    }

    private func detail(_ item: RecentItem) -> String {
        let when = abs(item.lastPlayed.timeIntervalSinceNow) < 60
            ? "just now" : RelativeDateTimeFormatter().localizedString(for: item.lastPlayed, relativeTo: Date())
        guard item.duration > 0 else { return when }
        let progress = item.isFinished ? "Finished" : "\(Timecode.string(item.position)) of \(Timecode.string(item.duration))"
        return "\(progress) · \(when)"
    }
}
