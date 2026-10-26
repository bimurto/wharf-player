import SwiftUI
import Core

struct PlayerScreen: View {
    @Bindable var model: AppModel
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    private var player: MPVPlayer { model.player }

    var body: some View {
        ZStack(alignment: .bottom) {
            MPVVideoView(player: player)
            if let error = player.errorMessage {
                Text("Playback failed: \(error)")
                    .padding(10).background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white).frame(maxHeight: .infinity)
            } else if model.currentURL != nil && !player.isLoaded {
                ProgressView().controlSize(.large).frame(maxHeight: .infinity)
            }
            if controlsVisible || player.paused {
                ControlsBar(player: player).padding(16).transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if controlsVisible || player.paused {
                Button("Open…") { model.showOpenSheet = true }.padding(12)
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
                Button("Play") {
                    if model.open(urlString: url, keyPath: keyPath) { model.showOpenSheet = false }
                }
                .keyboardShortcut(.defaultAction).disabled(url.isEmpty)
            }
        }
        .padding(20).frame(width: 520)
        .onAppear { keyPath = model.defaultKeyPath; model.openError = nil }
    }
}
