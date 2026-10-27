import Foundation
import Observation
import CMPV
import Core

/// Owns the libmpv handle and publishes playback state. Main-thread only.
@Observable
final class MPVPlayer {
    var position: Double = 0
    var duration: Double = 0
    var paused = true
    var volume: Double = 100
    var speed: Double = 1
    var title = ""
    var isLoaded = false
    /// Embedded subtitle tracks of the current file; empty until mpv reports them.
    var subtitleTracks: [SubtitleTrack] = []
    /// True once the user picked a track or Off for the current file; reset on load.
    /// Later automatic choices (external subtitle discovery, P1-24) must not override it.
    private(set) var userChoseSubtitle = false
    var errorMessage: String?
    /// Why the last `sub-add` failed; playback continues. Cleared on load and on the next attempt.
    var subtitleError: String?

    @ObservationIgnored private(set) var handle: OpaquePointer?
    /// Set by the video view so its render context is freed before the mpv handle.
    @ObservationIgnored var onShutdown: (() -> Void)?

    init() {
        handle = mpv_create()
        mpv_set_option_string(handle, "vo", "libmpv")
        mpv_set_option_string(handle, "msg-level", "all=warn,ffmpeg=error")
        mpv_set_option_string(handle, "hwdec", "auto-safe")
        mpv_set_option_string(handle, "cache", "yes")
        mpv_set_option_string(handle, "demuxer-max-bytes", "512MiB")
        mpv_set_option_string(handle, "demuxer-readahead-secs", "120")
        mpv_set_option_string(handle, "ytdl", "no")
        mpv_initialize(handle)
        for (name, format) in [("time-pos", MPV_FORMAT_DOUBLE), ("duration", MPV_FORMAT_DOUBLE),
                               ("pause", MPV_FORMAT_FLAG), ("volume", MPV_FORMAT_DOUBLE),
                               ("speed", MPV_FORMAT_DOUBLE), ("media-title", MPV_FORMAT_STRING),
                               ("track-list", MPV_FORMAT_STRING)] {
            mpv_observe_property(handle, 0, name, format)
        }
        mpv_set_wakeup_callback(handle, { ctx in
            let player = Unmanaged<MPVPlayer>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { player.drainEvents() }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: Commands

    func load(_ url: String, start: Double? = nil) {
        isLoaded = false
        errorMessage = nil
        position = start ?? 0
        duration = 0
        subtitleTracks = []
        userChoseSubtitle = false
        subtitleError = nil
        command(["loadfile", url, "replace", "-1"] + (start.map { ["start=\($0)"] } ?? []))
    }

    func togglePause() { command(["cycle", "pause"]) }
    func seek(to seconds: Double) { command(["seek", String(seconds), "absolute"]) }
    func seek(by seconds: Double) { command(["seek", String(seconds), "relative"]) }
    func setVolume(_ value: Double) { setDouble("volume", min(max(value, 0), 130)) }
    func setSpeed(_ value: Double) { setDouble("speed", value) }

    /// Shows embedded track `id`, or turns subtitles off when nil. The track-list observer updates `selected`.
    func setSubtitle(_ id: Int?) {
        userChoseSubtitle = true
        command(["set", "sid", SubtitleTrack.sidArgument(id)])
    }

    /// Adds the subtitle at `url` (a proxy or file URL), selects it and returns true on success.
    /// A user action: automatic choices must not override it. On failure `subtitleError` says why.
    /// mpv opens the file during the command, so this waits for the read.
    @discardableResult
    func addSubtitle(url: String, name: String) -> Bool {
        userChoseSubtitle = true
        subtitleError = nil
        let code = command(SubtitleTrack.subAddArguments(url: url, name: name))
        guard code < 0 else { return true }
        subtitleError = "Could not load \(name): \(String(cString: mpv_error_string(code)))"
        return false
    }

    func shutdown() {
        guard let h = handle else { return }
        onShutdown?()
        onShutdown = nil
        mpv_set_wakeup_callback(h, nil, nil)
        handle = nil
        mpv_terminate_destroy(h)
    }

    // MARK: Internals

    /// Runs an mpv command; returns its error code (negative) or 0 on success.
    @discardableResult
    private func command(_ args: [String]) -> Int32 {
        guard let handle else { return MPV_ERROR_UNINITIALIZED.rawValue }
        var cargs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) } + [nil]
        let code = mpv_command(handle, &cargs)
        cargs.forEach { free(UnsafeMutablePointer(mutating: $0)) }
        return code
    }

    private func setDouble(_ name: String, _ value: Double) {
        guard let handle else { return }
        var v = value
        mpv_set_property(handle, name, MPV_FORMAT_DOUBLE, &v)
    }

    private func drainEvents() {
        while let handle, let event = mpv_wait_event(handle, 0), event.pointee.event_id != MPV_EVENT_NONE {
            switch event.pointee.event_id {
            case MPV_EVENT_PROPERTY_CHANGE:
                guard let data = event.pointee.data else { continue }
                apply(data.assumingMemoryBound(to: mpv_event_property.self).pointee)
            case MPV_EVENT_FILE_LOADED:
                isLoaded = true
            case MPV_EVENT_END_FILE:
                let end = event.pointee.data.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                if end.reason == MPV_END_FILE_REASON_ERROR {
                    errorMessage = String(cString: mpv_error_string(end.error))
                }
            default: break
            }
        }
    }

    private func apply(_ prop: mpv_event_property) {
        guard let data = prop.data else { return }
        let name = String(cString: prop.name)
        if prop.format == MPV_FORMAT_DOUBLE {
            let v = data.assumingMemoryBound(to: Double.self).pointee
            switch name {
            case "time-pos": position = v
            case "duration": duration = v
            case "volume": volume = v
            case "speed": speed = v
            default: break
            }
        } else if prop.format == MPV_FORMAT_FLAG, name == "pause" {
            paused = data.assumingMemoryBound(to: Int32.self).pointee != 0
        } else if prop.format == MPV_FORMAT_STRING,
                  let cstr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee {
            // mpv hands the node property `track-list` over as JSON.
            if name == "media-title" { title = String(cString: cstr) }
            else if name == "track-list" { subtitleTracks = SubtitleTrack.parse(String(cString: cstr)) }
        }
    }
}
