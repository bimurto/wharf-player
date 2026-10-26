import Foundation
import Network
import CLibSSH

// Phase 0 spike: loopback HTTP proxy that serves one remote file with byte-range support,
// keeping many SFTP reads in flight (FFmpeg's libssh reader issues them one at a time).
// Host keys are checked against ~/.ssh/known_hosts; auth uses SPIKE_KEY or ssh-agent/default keys.

struct SFTPTarget {
    let host: String
    let port: Int
    let user: String
    let path: String
    let keyPath: String?

    /// Parses `sftp://user@host[:port]/path` without percent-decoding (names may contain spaces and brackets).
    init?(_ raw: String, keyPath: String?) {
        guard raw.hasPrefix("sftp://") else { return nil }
        let rest = raw.dropFirst("sftp://".count)
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let authority = rest[..<slash]
        let user = authority.split(separator: "@").first.map(String.init)
        let hostPort = authority.split(separator: "@").last.map(String.init) ?? ""
        let parts = hostPort.split(separator: ":")
        guard let user, authority.contains("@"), let host = parts.first else { return nil }
        self.user = user
        self.host = String(host)
        self.port = parts.count > 1 ? Int(parts[1]) ?? 22 : 22
        self.path = String(rest[slash...])
        self.keyPath = keyPath
    }
}

private func log(_ message: String) {
    FileHandle.standardError.write(Data("[proxy] \(message)\n".utf8))
}

/// One SSH session + open file. Not thread-safe: use from a single thread.
private final class SFTPFile {
    private var ssh: ssh_session?
    private var sftp: sftp_session?
    private var file: sftp_file?
    private(set) var size: UInt64 = 0

    init?(_ t: SFTPTarget) {
        guard let s = ssh_new() else { return nil }
        ssh = s
        var port = UInt32(t.port)
        ssh_options_set(s, SSH_OPTIONS_HOST, t.host)
        ssh_options_set(s, SSH_OPTIONS_PORT, &port)
        ssh_options_set(s, SSH_OPTIONS_USER, t.user)
        if let key = t.keyPath { ssh_options_set(s, SSH_OPTIONS_ADD_IDENTITY, key) }
        guard ssh_connect(s) == SSH_OK else { log("connect failed: \(String(cString: ssh_get_error(UnsafeMutableRawPointer(s))))"); close(); return nil }
        guard ssh_session_is_known_server(s) == SSH_KNOWN_HOSTS_OK else { log("host key not in known_hosts; connect once with ssh first"); close(); return nil }
        guard ssh_userauth_publickey_auto(s, nil, nil) == Int32(SSH_AUTH_SUCCESS.rawValue) else { log("public key auth failed"); close(); return nil }
        guard let sf = sftp_new(s), sftp_init(sf) == SSH_OK else { log("sftp init failed"); close(); return nil }
        sftp = sf
        guard let attrs = sftp_stat(sf, t.path) else { log("stat failed: sftp error \(sftp_get_error(sf)), \(String(cString: ssh_get_error(UnsafeMutableRawPointer(s)))), path=\(t.path)"); close(); return nil }
        size = attrs.pointee.size
        sftp_attributes_free(attrs)
        guard let f = sftp_open(sf, t.path, O_RDONLY, 0) else { log("open failed: sftp error \(sftp_get_error(sf))"); close(); return nil }
        file = f
    }

    deinit { close() }

    func close() {
        if let file { sftp_close(file); self.file = nil }
        if let sftp { sftp_free(sftp); self.sftp = nil }
        if let ssh { ssh_disconnect(ssh); ssh_free(ssh); self.ssh = nil }
    }

    /// Reads [start, end) in order with up to `depth` requests in flight; `emit` returns false to stop.
    func stream(start: UInt64, end: UInt64, chunk: Int, depth: Int, emit: (Data) -> Bool) {
        guard let file else { return }
        sftp_seek64(file, start)
        var inflight: [(id: Int32, len: Int)] = []
        var next = start
        var buf = [UInt8](repeating: 0, count: chunk)
        while true {
            while inflight.count < depth && next < end {
                let len = Int(min(UInt64(chunk), end - next))
                let id = sftp_async_read_begin(file, UInt32(len))
                if id < 0 { log("read_begin failed"); return }
                inflight.append((id, len))
                next += UInt64(len)
            }
            guard !inflight.isEmpty else { return }
            let req = inflight.removeFirst()
            let n = buf.withUnsafeMutableBytes { Int(sftp_async_read(file, $0.baseAddress, UInt32(req.len), UInt32(req.id))) }
            if n <= 0 { if n < 0 { log("read failed") }; return }
            if n < req.len { log("short read \(n)/\(req.len); server caps read size"); return }
            if !emit(Data(buf[0..<n])) { return }
        }
    }
}

final class SFTPProxy {
    private let target: SFTPTarget
    private let listener: NWListener
    private let workers = DispatchQueue(label: "proxy.workers", attributes: .concurrent)
    private(set) var port: UInt16 = 0

    init?(target: SFTPTarget) {
        self.target = target
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        guard let l = try? NWListener(using: params) else { return nil }
        listener = l
        let ready = DispatchSemaphore(value: 0)
        l.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        l.start(queue: workers)
        guard ready.wait(timeout: .now() + 5) == .success, let p = l.port?.rawValue else { return nil }
        port = p
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: workers)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let head = String(data: data, encoding: .utf8) else { conn.cancel(); return }
            self.workers.async { self.respond(conn, head: head) }
        }
    }

    private func respond(_ conn: NWConnection, head: String) {
        defer { conn.cancel() }
        let isHead = head.hasPrefix("HEAD ")
        guard let file = SFTPFile(target) else { send(conn, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"); return }
        let size = file.size
        var start: UInt64 = 0, end = size
        var status = "200 OK", extra = ""
        if let r = head.range(of: #"(?i)range:\s*bytes=(\d*)-(\d*)"#, options: .regularExpression) {
            let spec = head[r].split(separator: "=")[1].split(separator: "-", omittingEmptySubsequences: false)
            if let s = UInt64(spec[0]) {
                start = s
                if spec.count > 1, let e = UInt64(spec[1]) { end = min(e + 1, size) }
            } else if spec.count > 1, let suffix = UInt64(spec[1]) {
                start = size - min(suffix, size)
            }
            guard start < size else { send(conn, "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */\(size)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"); return }
            status = "206 Partial Content"
            extra = "Content-Range: bytes \(start)-\(end - 1)/\(size)\r\n"
        }
        send(conn, "HTTP/1.1 \(status)\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\n\(extra)Content-Length: \(end - start)\r\nConnection: close\r\n\r\n")
        if isHead { return }
        log("serving \(start)..<\(end)")
        file.stream(start: start, end: end, chunk: 65536, depth: 32) { send(conn, $0) }
    }

    /// Blocks until the bytes are handed to the kernel; false once the client has gone away (e.g. mpv seeked).
    @discardableResult
    private func send(_ conn: NWConnection, _ string: String) -> Bool { send(conn, Data(string.utf8)) }

    @discardableResult
    private func send(_ conn: NWConnection, _ data: Data) -> Bool {
        let done = DispatchSemaphore(value: 0)
        var ok = true
        conn.send(content: data, completion: .contentProcessed { if $0 != nil { ok = false }; done.signal() })
        done.wait()
        return ok
    }
}
