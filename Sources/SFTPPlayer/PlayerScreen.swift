import SwiftUI
import Core
import AppKit
import UniformTypeIdentifiers

struct PlayerScreen: View {
    @Bindable var model: AppModel
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var sidebarWidth = SidebarWidthStore.defaultWidth
    @State private var dragStartWidth: Double?
    @FocusState private var dividerFocused: Bool

    private var player: MPVPlayer { model.player }

    var body: some View {
        GeometryReader { window in split(windowWidth: window.size.width) }
            .onAppear { sidebarWidth = model.sidebarWidth.saved ?? SidebarWidthStore.defaultWidth }
    }

    private func split(windowWidth: Double) -> some View {
        HStack(spacing: 0) {
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
                    case .recents: RecentsPanel(model: model)
                    }
                }
                .frame(width: SidebarWidthStore.clamped(sidebarWidth, windowWidth: windowWidth))
                divider(windowWidth: windowWidth)
            }
            playerArea.frame(minWidth: 480)
        }
    }

    /// The draggable divider; focus it to resize with the arrow keys (Shift for bigger steps), Home and End.
    private func divider(windowWidth: Double) -> some View {
        let current = SidebarWidthStore.clamped(sidebarWidth, windowWidth: windowWidth)
        func resize(_ action: SidebarWidthStore.Resize, large: Bool = false) {
            sidebarWidth = SidebarWidthStore.resized(current, action, large: large, windowWidth: windowWidth)
            model.sidebarWidth.save(sidebarWidth)
        }
        return Rectangle()
            .fill(dividerFocused ? Theme.gold : Color(nsColor: .separatorColor))
            .frame(width: dividerFocused ? 3 : 1)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { drag in
                    let start = dragStartWidth ?? current
                    dragStartWidth = start
                    sidebarWidth = SidebarWidthStore.clamped(start + drag.translation.width, windowWidth: windowWidth)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    model.sidebarWidth.save(sidebarWidth)
                })
            .focusable()
            .focused($dividerFocused)
            .focusEffectDisabled()
            .onKeyPress(.leftArrow, phases: [.down, .repeat]) { press in
                resize(.narrower, large: press.modifiers.contains(.shift)); return .handled
            }
            .onKeyPress(.rightArrow, phases: [.down, .repeat]) { press in
                resize(.wider, large: press.modifiers.contains(.shift)); return .handled
            }
            .onKeyPress(.home) { resize(.minimum); return .handled }
            .onKeyPress(.end) { resize(.maximum); return .handled }
            .accessibilityElement()
            .accessibilityLabel("Sidebar divider")
            .accessibilityValue("\(Int(current)) points wide")
            .accessibilityAdjustableAction { direction in
                resize(direction == .increment ? .wider : .narrower)
            }
    }

    private var playerArea: some View {
        ZStack(alignment: .bottom) {
            MPVVideoView(player: player, onMouseMoved: revealControls, onClick: { model.showSidebar = false },
                         onSibling: model.playSibling)
            if model.currentURL == nil { WelcomeView(model: model) }
            if let error = player.errorMessage {
                Text("Playback failed: \(error)")
                    .padding(10).background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white).frame(maxHeight: .infinity)
            } else if model.currentURL != nil && !player.isLoaded {
                ProgressView().controlSize(.large).frame(maxHeight: .infinity)
            }
            if let error = player.subtitleError {
                Text(error)
                    .padding(8).background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white).frame(maxHeight: .infinity, alignment: .top).padding(.top, 48)
            }
            if model.currentURL != nil && (controlsVisible || player.paused) {
                Text(fileName)
                    .font(.headline).lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxHeight: .infinity, alignment: .top).padding(16).transition(.opacity)
                ControlsBar(player: player, externalSubtitles: model.externalSubtitles,
                            onAddSubtitle: model.loadExternalSubtitle,
                            onToggleSidebar: { model.showSidebar.toggle() },
                            previous: model.previousEntry, next: model.nextEntry,
                            onSibling: model.playSibling).padding(16).transition(.opacity)
            }
        }
        .background(Theme.black)
        .onContinuousHover { if case .active = $0 { revealControls() } }
        .onChange(of: player.position) { model.saveProgressThrottled() }
        .sheet(isPresented: $model.showOpenSheet) { OpenSheet(model: model) }
    }

    /// The playing file's name, as the recents list titles it.
    private var fileName: String {
        if !player.title.isEmpty { return player.title }
        let last = ((model.currentURL ?? "") as NSString).lastPathComponent
        return last.removingPercentEncoding ?? last
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
    /// Subtitle files found on the server beside the video.
    let externalSubtitles: [ExternalSubtitle]
    let onAddSubtitle: (ExternalSubtitle) -> Void
    let onToggleSidebar: () -> Void
    /// The videos before and after this one in its folder; nil disables the button.
    let previous: RemoteEntry?
    let next: RemoteEntry?
    let onSibling: (Int) -> Void
    @State private var scrub: Double?

    private static let speeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    /// Asks for a local subtitle file and loads it through the same `sub-add` path as server files.
    private func chooseLocalSubtitle() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ExternalSubtitles.extensions.sorted().compactMap { UTType(filenameExtension: $0) }
        panel.message = "Choose a subtitle file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = player.addSubtitle(url: url.absoluteString, name: url.lastPathComponent)
    }

    /// Lists embedded and loaded external tracks, Off, and server subtitle files not yet loaded;
    /// the current choice carries a checkmark.
    private var subtitleMenu: some View {
        let tracks = player.subtitleTracks
        let available = ExternalSubtitles.notLoaded(externalSubtitles, tracks: tracks)
        return Menu {
            Text(tracks.isEmpty ? "No subtitles" : "\(tracks.count) subtitle track\(tracks.count == 1 ? "" : "s")")
            Divider()
            Button { player.setSubtitle(nil) } label: {
                if SubtitleTrack.isOff(tracks) { Label("Off", systemImage: "checkmark") } else { Text("Off") }
            }
            ForEach(tracks) { track in
                Button { player.setSubtitle(track.id) } label: {
                    if track.selected { Label(track.label, systemImage: "checkmark") } else { Text(track.label) }
                }
            }
            Divider()
            Menu("Sync: \(SubtitleSync.label(player.subtitleDelay))") {
                Button("Earlier (-0.5 s)") { player.stepSubtitleDelay(-1) }
                    .disabled(!SubtitleSync.canStep(player.subtitleDelay, by: -1))
                Button("Later (+0.5 s)") { player.stepSubtitleDelay(1) }
                    .disabled(!SubtitleSync.canStep(player.subtitleDelay, by: 1))
                Button("Reset") { player.resetSubtitleDelay() }
                    .disabled(player.subtitleDelay == 0)
            }
            Menu("Size: \(SubtitleAppearance.scaleLabel(player.subtitleScale))") {
                Button("Smaller") { player.stepSubtitleScale(-1) }
                    .disabled(!SubtitleAppearance.canStepScale(player.subtitleScale, by: -1))
                Button("Bigger") { player.stepSubtitleScale(1) }
                    .disabled(!SubtitleAppearance.canStepScale(player.subtitleScale, by: 1))
            }
            Menu("Position: \(SubtitleAppearance.positionLabel(player.subtitlePosition))") {
                Button("Up") { player.stepSubtitlePosition(up: true) }
                    .disabled(!SubtitleAppearance.canStepPosition(player.subtitlePosition, up: true))
                Button("Down") { player.stepSubtitlePosition(up: false) }
                    .disabled(!SubtitleAppearance.canStepPosition(player.subtitlePosition, up: false))
            }
            Button("Reset size and position") { player.resetSubtitleAppearance() }
                .disabled(player.subtitleScale == SubtitleAppearance.defaultScale
                          && player.subtitlePosition == SubtitleAppearance.defaultPosition)
            Divider()
            Button("Choose file…") { chooseLocalSubtitle() }
            if !available.isEmpty {
                Section("On the server") {
                    ForEach(available) { sub in
                        Button(sub.name) { onAddSubtitle(sub) }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .menuStyle(.button).menuIndicator(.hidden).fixedSize()
        .help("Subtitles")
    }

    /// Lists the audio tracks with a checkmark on the playing one; the caller shows it only for 2+ tracks.
    private var audioMenu: some View {
        Menu {
            ForEach(player.audioTracks) { track in
                Button { player.setAudioTrack(track.id) } label: {
                    if track.selected { Label(track.label, systemImage: "checkmark") } else { Text(track.label) }
                }
            }
        } label: {
            Image(systemName: "waveform")
        }
        .menuStyle(.button).menuIndicator(.hidden).fixedSize()
        .help("Audio track")
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSidebar) { Image(systemName: "sidebar.left") }
                .help("Library, Servers and Recents")

            Button { onSibling(-1) } label: { Image(systemName: "backward.end.fill") }
                .disabled(previous == nil)
                .help(previous.map { "Previous: \($0.name) (P)" } ?? "No previous video in this folder")

            Button { player.togglePause() } label: {
                Image(systemName: player.paused ? "play.fill" : "pause.fill").frame(width: 18)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(player.paused ? "Play" : "Pause")

            Button { onSibling(1) } label: { Image(systemName: "forward.end.fill") }
                .disabled(next == nil)
                .help(next.map { "Next: \($0.name) (N)" } ?? "No next video in this folder")

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

            if player.audioTracks.count > 1 { audioMenu }

            subtitleMenu

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
