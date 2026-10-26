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

struct Failure: Error, ExpressibleByStringLiteral, CustomStringConvertible {
    let description: String
    init(stringLiteral value: String) { description = value }
    init(_ value: String) { description = value }
}

private func log(_ message: String) {
    FileHandle.standardError.write(Data("[proxy] \(message)\n".utf8))
}

/// One authenticated SSH+SFTP session. Not thread-safe: owned by one request at a time.
private final class SFTPSession {
    private var ssh: ssh_session?
    private var sftp: sftp_session?
    /// Set when a read failed or the stream was cut with unread data; such a session is not reused.
    var broken = false

    private static func sshError(_ s: ssh_session) -> String {
        String(cString: ssh_get_error(UnsafeMutableRawPointer(s)))
    }

    /// Connects, verifies the host key against known_hosts, and authenticates. Returns a reason on failure.
    static func connect(_ t: SFTPTarget) -> Result<SFTPSession, Failure> {
        guard let s = ssh_new() else { return .failure("ssh_new failed") }
        let session = SFTPSession()
        session.ssh = s
        var port = UInt32(t.port)
        ssh_options_set(s, SSH_OPTIONS_HOST, t.host)
        ssh_options_set(s, SSH_OPTIONS_PORT, &port)
        ssh_options_set(s, SSH_OPTIONS_USER, t.user)
        if let key = t.keyPath { ssh_options_set(s, SSH_OPTIONS_ADD_IDENTITY, key) }
        guard ssh_connect(s) == SSH_OK else { return .failure(Failure("connect: \(sshError(s))")) }
        guard ssh_session_is_known_server(s) == SSH_KNOWN_HOSTS_OK else { return .failure("host key not in known_hosts; connect once with ssh first") }
        guard ssh_userauth_publickey_auto(s, nil, nil) == Int32(SSH_AUTH_SUCCESS.rawValue) else { return .failure(Failure("public key auth failed: \(sshError(s))")) }
        guard let sf = sftp_new(s), sftp_init(sf) == SSH_OK else { return .failure(Failure("sftp init: \(sshError(s))")) }
        session.sftp = sf
        return .success(session)
    }

    deinit {
        if let sftp { sftp_free(sftp) }
        if let ssh { ssh_disconnect(ssh); ssh_free(ssh) }
    }

    /// Opens `path` read-only; the size comes from the open handle's attributes.
    func open(_ path: String) -> Result<(file: sftp_file, size: UInt64), Failure> {
        guard let sftp, let ssh else { return .failure("session closed") }
        guard let f = sftp_open(sftp, path, O_RDONLY, 0) else {
            return .failure(Failure("open \(path): sftp error \(sftp_get_error(sftp)), \(SFTPSession.sshError(ssh))"))
        }
        guard let attrs = sftp_fstat(f) else { sftp_close(f); return .failure(Failure("fstat: sftp error \(sftp_get_error(sftp))")) }
        defer { sftp_attributes_free(attrs) }
        return .success((f, attrs.pointee.size))
    }

    /// Reads [start, end) in order with up to `depth` requests in flight; `emit` returns false to stop.
    /// Always drains outstanding requests and closes the handle so the session stays usable.
    func stream(_ file: sftp_file, start: UInt64, end: UInt64, chunk: Int, depth: Int, emit: (Data) -> Bool) {
        sftp_seek64(file, start)
        var inflight: [(id: Int32, len: Int)] = []
        var next = start
        var buf = [UInt8](repeating: 0, count: chunk)
        func read(_ req: (id: Int32, len: Int)) -> Int {
            buf.withUnsafeMutableBytes { Int(sftp_async_read(file, $0.baseAddress, UInt32(req.len), UInt32(req.id))) }
        }
        loop: while true {
            while inflight.count < depth && next < end {
                let len = Int(min(UInt64(chunk), end - next))
                let id = sftp_async_read_begin(file, UInt32(len))
                if id < 0 { log("read_begin failed"); broken = true; break loop }
                inflight.append((id, len))
                next += UInt64(len)
            }
            guard !inflight.isEmpty else { break }
            let req = inflight.removeFirst()
            let n = read(req)
            if n < 0 { log("read failed"); broken = true; break }
            if n == 0 { break }
            if n < req.len { log("short read \(n)/\(req.len); server caps read size"); broken = true; break }
            if !emit(Data(buf[0..<n])) { break }
        }
        if !broken { for req in inflight where read(req) < 0 { broken = true; break } }
        sftp_close(file)
    }
}

/// Reuses authenticated sessions (seedboxes often limit simultaneous logins) and retries connects.
private final class SFTPSessionPool {
    private let target: SFTPTarget
    private let slots = DispatchSemaphore(value: 3)
    private let lock = NSLock()
    private var idle: [SFTPSession] = []

    init(_ target: SFTPTarget) { self.target = target }

    /// Runs `body` with exclusive use of a session; the session returns to the pool unless `broken`.
    func withSession<T>(_ body: (SFTPSession) -> T) -> Result<T, Failure> {
        slots.wait()
        defer { slots.signal() }
        lock.lock(); let reused = idle.popLast(); lock.unlock()
        var session = reused
        var lastError: Failure = "no attempts"
        for attempt in 0..<3 where session == nil {
            switch SFTPSession.connect(target) {
            case .success(let s): session = s
            case .failure(let e):
                lastError = e
                log("\(e.description) (attempt \(attempt + 1)/3)")
                Thread.sleep(forTimeInterval: 0.5 * Double(attempt + 1))
            }
        }
        guard let session else { return .failure(lastError) }
        let result = body(session)
        if !session.broken { lock.lock(); idle.append(session); lock.unlock() }
        return .success(result)
    }
}

final class SFTPProxy {
    private let target: SFTPTarget
    private let pool: SFTPSessionPool
    private let listener: NWListener
    private let workers = DispatchQueue(label: "proxy.workers", attributes: .concurrent)
    private(set) var port: UInt16 = 0

    init?(target: SFTPTarget) {
        self.target = target
        pool = SFTPSessionPool(target)
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
        let outcome: Result<String?, Failure> = pool.withSession { session in
            switch session.open(self.target.path) {
            case .failure(let e):
                // A failed open may mean the pooled session went stale; do not return it to the pool.
                session.broken = true
                return e.description
            case .success(let (file, size)):
                self.serve(conn, session: session, file: file, size: size, head: head, isHead: isHead)
                return nil
            }
        }
        let reason: String?
        switch outcome {
        case .failure(let e): reason = e.description
        case .success(let r): reason = r
        }
        if let reason {
            log("502: \(reason)")
            send(conn, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        }
    }

    private func serve(_ conn: NWConnection, session: SFTPSession, file: sftp_file, size: UInt64, head: String, isHead: Bool) {
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
            guard start < size else {
                sftp_close(file)
                send(conn, "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */\(size)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                return
            }
            status = "206 Partial Content"
            extra = "Content-Range: bytes \(start)-\(end - 1)/\(size)\r\n"
        }
        send(conn, "HTTP/1.1 \(status)\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\n\(extra)Content-Length: \(end - start)\r\nConnection: close\r\n\r\n")
        if isHead { sftp_close(file); return }
        log("serving \(start)..<\(end)")
        session.stream(file, start: start, end: end, chunk: 65536, depth: 32) { send(conn, $0) }
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
