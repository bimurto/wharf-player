import AppKit
import OpenGL.GL3
import CMPV
import Core

// Phase 0 spike: render one mpv stream (URL from SPIKE_URL) into an NSOpenGLView.
// Credentials come from the environment only; nothing is logged or stored.

final class MPVGLView: NSOpenGLView {
    private var mpv: OpaquePointer?
    private var renderCtx: OpaquePointer?

    override init?(frame: NSRect, pixelFormat: NSOpenGLPixelFormat?) {
        super.init(frame: frame, pixelFormat: pixelFormat)
        wantsBestResolutionOpenGLSurface = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func start(url: String) {
        openGLContext?.makeCurrentContext()
        mpv = mpv_create()
        mpv_set_option_string(mpv, "vo", "libmpv")
        mpv_set_option_string(mpv, "terminal", "yes")
        mpv_set_option_string(mpv, "msg-level", ProcessInfo.processInfo.environment["SPIKE_LOG"] ?? "all=warn,ffmpeg=error")
        if let key = ProcessInfo.processInfo.environment["SPIKE_KEY"] {
            mpv_set_option_string(mpv, "stream-lavf-o", "private_key=\(key)")
        }
        mpv_set_option_string(mpv, "cache", "yes")
        mpv_set_option_string(mpv, "demuxer-max-bytes", "512MiB")
        mpv_set_option_string(mpv, "demuxer-readahead-secs", "120")
        mpv_initialize(mpv)

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
                mpv_render_context_create(&renderCtx, mpv, &params)
            }
        }
        mpv_render_context_set_update_callback(renderCtx, { ctx in
            let view = Unmanaged<MPVGLView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { view.needsDisplay = true }
        }, Unmanaged.passUnretained(self).toOpaque())

        var cargs: [UnsafePointer<CChar>?] = [UnsafePointer(strdup("loadfile")), UnsafePointer(strdup(url)), nil]
        _ = mpv_command(mpv, &cargs)
        cargs.forEach { free(UnsafeMutablePointer(mutating: $0)) }
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

    override func keyDown(with event: NSEvent) {
        guard let mpv else { return }
        switch event.charactersIgnoringModifiers {
        case " ": mpv_command_string(mpv, "cycle pause")
        case "\u{F702}": mpv_command_string(mpv, "seek -10")
        case "\u{F703}": mpv_command_string(mpv, "seek 10")
        default: break
        }
    }
    override var acceptsFirstResponder: Bool { true }

    /// Stops playback and releases mpv. The render context must be freed before the mpv handle.
    func shutdown() {
        openGLContext?.makeCurrentContext()
        if let renderCtx {
            mpv_render_context_set_update_callback(renderCtx, nil, nil)
            mpv_render_context_free(renderCtx)
            self.renderCtx = nil
        }
        if let mpv {
            mpv_terminate_destroy(mpv)
            self.mpv = nil
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var view: MPVGLView?
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { view?.shutdown() }
}

guard let url = ProcessInfo.processInfo.environment["SPIKE_URL"] else {
    FileHandle.standardError.write(Data("Set SPIKE_URL=sftp://user:pass@host/path (optional SPIKE_KEY=/path/to/key)\n".utf8))
    exit(2)
}

let env = ProcessInfo.processInfo.environment
if let dir = env["SPIKE_LIST"], let target = SFTPTarget(url, keyPath: env["SPIKE_KEY"]) {
    if let kh = env["SPIKE_KNOWN_HOSTS"] { KnownHosts.path = kh }
    let browser = SFTPBrowser(pool: SFTPSessionPool(target))
    Task {
        var result = await browser.list(dir)
        if case .failure(let f) = result, case .unknown(let fp)? = f.hostKey {
            print("UNTRUSTED \(fp.hostLabel) \(fp.keyType) \(fp.sha256)")
            if env["SPIKE_TRUST"] != nil {
                print("trust ->", KnownHosts.trust(fp, target: target))
                result = await browser.list(dir)
            }
        } else if case .failure(let f) = result, case .changed(let fp)? = f.hostKey {
            print("CHANGED \(fp.sha256)")
        }
        switch result {
        case .success(let entries):
            for e in Library.sorted(entries, by: .modifiedNewest).prefix(8) {
                print("\(e.isDirectory ? "d" : "-") \(e.size) \(e.modified?.description ?? "-") \(e.name)")
            }
            print("total \(entries.count)")
        case .failure(let f): print("FAILED: \(f)")
        }
        exit(0)
    }
    RunLoop.main.run()
}
var proxy: SFTPProxy?
var playURL = url
if env["SPIKE_PROXY"] != nil {
    guard let target = SFTPTarget(url, keyPath: env["SPIKE_KEY"]), let p = SFTPProxy(target: target) else {
        FileHandle.standardError.write(Data("Could not start proxy (check URL and known_hosts)\n".utf8))
        exit(1)
    }
    proxy = p
    playURL = p.url(for: target.path)
}

if env["SPIKE_HEADLESS"] != nil, let proxy {
    print("PORT=\(proxy.port)")
    print("URL=\(playURL)")
    fflush(stdout)
    RunLoop.main.run()
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let attrs: [NSOpenGLPixelFormatAttribute] = [
    UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
    UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated), 0,
]
let view = MPVGLView(frame: NSRect(x: 0, y: 0, width: 960, height: 540), pixelFormat: NSOpenGLPixelFormat(attributes: attrs))!
let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
let delegate = AppDelegate()
delegate.view = view
app.delegate = delegate
window.contentView = view
window.title = "Spike"
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)
app.activate(ignoringOtherApps: true)
view.start(url: playURL)
app.run()
