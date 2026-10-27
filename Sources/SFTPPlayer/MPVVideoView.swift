import AppKit
import OpenGL.GL3
import SwiftUI
import CMPV

/// Renders the player's frames with the libmpv render API and handles keyboard shortcuts.
final class MPVGLView: NSOpenGLView {
    private let player: MPVPlayer
    private var renderCtx: OpaquePointer?
    /// Called on every mouse move over the video, so the controls can reappear.
    var onMouseMoved: (() -> Void)?
    /// Called on every click on the video.
    var onClick: (() -> Void)?

    init(player: MPVPlayer) {
        self.player = player
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated), 0,
        ]
        super.init(frame: .zero, pixelFormat: NSOpenGLPixelFormat(attributes: attrs))!
        wantsBestResolutionOpenGLSurface = true
        wantsLayer = true   // lets SwiftUI controls composite above the video
        player.onShutdown = { [weak self] in self?.freeRenderContext() }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()
        let getProc: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? = { _, name in
            guard let name else { return nil }
            let bundle = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString)
            return CFBundleGetFunctionPointerForName(bundle, String(cString: name) as CFString)
        }
        var gl = mpv_opengl_init_params(get_proc_address: getProc, get_proc_address_ctx: nil)
        var advanced: CInt = 1
        let apiType = strdup(MPV_RENDER_API_TYPE_OPENGL)
        defer { free(apiType) }
        withUnsafeMutablePointer(to: &gl) { glPtr in
            withUnsafeMutablePointer(to: &advanced) { advPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: apiType),
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: glPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_ADVANCED_CONTROL, data: advPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
                ]
                mpv_render_context_create(&renderCtx, player.handle, &params)
            }
        }
        mpv_render_context_set_update_callback(renderCtx, { ctx in
            let view = Unmanaged<MPVGLView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { view.needsDisplay = true }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func freeRenderContext() {
        guard let renderCtx else { return }
        openGLContext?.makeCurrentContext()
        mpv_render_context_set_update_callback(renderCtx, nil, nil)
        mpv_render_context_free(renderCtx)
        self.renderCtx = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let renderCtx else { return }
        openGLContext?.makeCurrentContext()
        // ADVANCED_CONTROL requires update() before every render, or mpv never advances.
        _ = mpv_render_context_update(renderCtx)
        let size = convertToBacking(bounds).size
        var fbo = mpv_opengl_fbo(fbo: 0, w: CInt(size.width), h: CInt(size.height), internal_format: 0)
        var flip: CInt = 1
        withUnsafeMutablePointer(to: &fbo) { fboPtr in
            withUnsafeMutablePointer(to: &flip) { flipPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: flipPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
                ]
                mpv_render_context_render(renderCtx, &params)
            }
        }
        openGLContext?.flushBuffer()
        mpv_render_context_report_swap(renderCtx)
    }

    override var acceptsFirstResponder: Bool { true }

    // SwiftUI's own hover tracking goes stale when the layout changes (for example when the sidebar
    // closes), so the controls would stay hidden. A tracking area covering the visible rect is kept
    // current by AppKit on every resize.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { onMouseMoved?() }

    override func keyDown(with event: NSEvent) {
        let big = event.modifierFlags.contains(.shift)
        switch event.charactersIgnoringModifiers {
        case " ": player.togglePause()
        case "\u{F702}": player.seek(by: big ? -60 : -10)
        case "\u{F703}": player.seek(by: big ? 60 : 10)
        case "\u{F700}": player.setVolume(player.volume + 5)
        case "\u{F701}": player.setVolume(player.volume - 5)
        case "f": window?.toggleFullScreen(nil)
        default: super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?()
        if event.clickCount == 2 { window?.toggleFullScreen(nil) }
    }
}

struct MPVVideoView: NSViewRepresentable {
    let player: MPVPlayer
    let onMouseMoved: () -> Void
    let onClick: () -> Void

    func makeNSView(context: Context) -> MPVGLView {
        let view = MPVGLView(player: player)
        view.onMouseMoved = onMouseMoved
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: MPVGLView, context: Context) {
        view.onMouseMoved = onMouseMoved
        view.onClick = onClick
    }
}
