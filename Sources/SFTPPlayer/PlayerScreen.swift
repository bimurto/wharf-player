import SwiftUI
import Core

struct PlayerScreen: View {
    @Bindable var model: AppModel
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    private var player: MPVPlayer { model.player }

    var body: some View {
        HSplitView {
            if model.showSidebar {
                VStack(spacing: 0) {
                    Picker("Panel", selection: $model.sidebarPanel) {
                        ForEach(AppModel.SidebarPanel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().padding(10)
                    Divider()
                    switch model.sidebarPanel {
                    case .library: LibraryPanel(model: model, library: model.library)
                    case .servers: ServersPanel(model: model)
                    }
                }
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 640)
            }
            playerArea.frame(minWidth: 480)
        }
    }

    private var playerArea: some View {
        ZStack(alignment: .bottom) {
            MPVVideoView(player: player, onMouseMoved: revealControls)
            if let error = player.errorMessage {
                Text("Playback failed: \(error)")
                    .padding(10).background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white).frame(maxHeight: .infinity)
            } else if model.currentURL != nil && !player.isLoaded {
                ProgressView().controlSize(.large).frame(maxHeight: .infinity)
            }
            if model.currentURL != nil && (controlsVisible || player.paused) {
                ControlsBar(player: player).padding(16).transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if controlsVisible || player.paused || model.currentURL == nil {
                HStack {
                    ForEach(AppModel.SidebarPanel.allCases, id: \.self) { panel in
                        Button(panel.rawValue) { model.toggleSidebar(panel) }
                    }
                    Button("Open…") { model.showOpenSheet = true }
                }
                .padding(12)
            }
        }
        .background(.black)
        .onContinuousHover { if case .active = $0 { revealControls() } }
        .onChange(of: player.position) { model.saveProgressThrottled() }
        .sheet(isPresented: $model.showOpenSheet) { OpenSheet(model: model) }
        .onAppear { if model.currentURL == nil { model.showOpenSheet = true } }
    }

    /// Shows the controls and hides them again after 2.8 s of no mouse movement.
    private func revealControls() {
        withAnimation(.easeOut(duration: 0.15)) { controlsVisible = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.3)) { controlsVisible = false } }
        }
    }
}

private struct ControlsBar: View {
    let player: MPVPlayer
    @State private var scrub: Double?

    private static let speeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        HStack(spacing: 12) {
            Button { player.togglePause() } label: {
                Image(systemName: player.paused ? "play.fill" : "pause.fill").frame(width: 18)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(player.paused ? "Play" : "Pause")

            Text(Timecode.string(scrub ?? player.position)).monospacedDigit()
            Slider(value: Binding(get: { scrub ?? player.position }, set: { scrub = $0 }),
                   in: 0...max(player.duration, 1)) { editing in
                if !editing, let value = scrub { player.seek(to: value); scrub = nil }
            }
            Text(Timecode.string(player.duration)).monospacedDigit()

            Image(systemName: "speaker.wave.2.fill")
            Slider(value: Binding(get: { player.volume }, set: { player.setVolume($0) }), in: 0...130)
                .frame(width: 90)

            Menu("\(player.speed.formatted())×") {
                ForEach(Self.speeds, id: \.self) { s in Button("\(s.formatted())×") { player.setSpeed(s) } }
            }
            .menuStyle(.button).fixedSize()

            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Full screen")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct OpenSheet: View {
    @Bindable var model: AppModel
    @State private var url = ""
    @State private var keyPath = ""
    @State private var opening = false
    @State private var hostKeyIssue: HostKeyIssue?
    @State private var pendingTarget: SFTPTarget?

    private func play() {
        opening = true
        Task {
            defer { opening = false }
            switch await model.open(urlString: url, keyPath: keyPath) {
            case .started: model.showOpenSheet = false
            case .failed: break
            case .hostKey(let issue, let target): pendingTarget = target; hostKeyIssue = issue
            }
        }
    }

    private func trustAndPlay(_ fingerprint: HostKeyFingerprint) {
        guard let target = pendingTarget else { return }
        Task {
            if let failure = await model.trust(fingerprint, target: target) {
                model.openError = failure.description
            } else {
                play()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open media").font(.headline)
            TextField("sftp://user@host/path/to/video.mkv", text: $url)
                .textFieldStyle(.roundedBorder)
            TextField("Key file (blank uses ssh-agent and default keys)", text: $keyPath)
                .textFieldStyle(.roundedBorder)
            if let error = model.openError {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.showOpenSheet = false }.keyboardShortcut(.cancelAction)
                if opening { ProgressView().controlSize(.small) }
                Button("Play") { play() }
                    .keyboardShortcut(.defaultAction).disabled(url.isEmpty || opening)
            }
        }
        .padding(20).frame(width: 520)
        .hostKeyDialog($hostKeyIssue, onTrust: trustAndPlay)
        .onAppear {
            keyPath = model.defaultKeyPath
            model.openError = nil
        }
    }
}
