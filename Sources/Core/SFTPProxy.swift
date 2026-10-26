import Foundation
import Network
import CLibSSH

// Phase 0 spike: loopback HTTP proxy that serves one remote file with byte-range support,
// keeping many SFTP reads in flight (FFmpeg's libssh reader issues them one at a time).
// Host keys are checked against ~/.ssh/known_hosts; auth uses SPIKE_KEY or ssh-agent/default keys.

public struct SFTPTarget: Sendable {
    public let host: String
    public let port: Int
    public let user: String
    public let path: String
    public let keyPath: String?
    /// Account password; when set, password auth is used instead of keys.
    public let password: String?
    /// Passphrase for an encrypted key.
    public let passphrase: String?

    public init(host: String, port: Int = 22, user: String, path: String = "/", keyPath: String? = nil,
                password: String? = nil, passphrase: String? = nil) {
        self.host = host; self.port = port; self.user = user; self.path = path; self.keyPath = keyPath
        self.password = password; self.passphrase = passphrase
    }

    /// The same server and credentials for a different remote path.
    public func with(path: String) -> SFTPTarget {
        SFTPTarget(host: host, port: port, user: user, path: path, keyPath: keyPath, password: password, passphrase: passphrase)
    }

    /// Parses `sftp://user@host[:port]/path` without percent-decoding (names may contain spaces and brackets).
    public init?(_ raw: String, keyPath: String?) {
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
        self.password = nil
        self.passphrase = nil
    }
}

public struct Failure: Error, ExpressibleByStringLiteral, CustomStringConvertible, Sendable {
    public let description: String
    /// Set when the server's host key is not trusted yet or has changed.
    public let hostKey: HostKeyIssue?
    /// False for failures a retry cannot fix (and could trip login lockouts): host key and authentication.
    public let retryable: Bool
    public init(stringLiteral value: String) { description = value; hostKey = nil; retryable = true }
    public init(_ value: String, hostKey: HostKeyIssue? = nil, retryable: Bool = true) {
        description = value; self.hostKey = hostKey; self.retryable = retryable
    }
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("[proxy] \(message)\n".utf8))
}

/// One authenticated SSH+SFTP session. Not thread-safe: owned by one request at a time.
final class SFTPSession {
    private var ssh: ssh_session?
    private var sftp: sftp_session?
    /// Set when a read failed or the stream was cut with unread data; such a session is not reused.
    var broken = false

    private static func sshError(_ s: ssh_session) -> String {
        String(cString: ssh_get_error(UnsafeMutableRawPointer(s)))
    }

    /// Options shared by every connection. The user's ssh config is ignored so behaviour is the same on every machine.
    static func configure(_ s: ssh_session, _ t: SFTPTarget) {
        var port = UInt32(t.port)
        var timeout: Int = 15
        var processConfig = false
        ssh_options_set(s, SSH_OPTIONS_PROCESS_CONFIG, &processConfig)
        ssh_options_set(s, SSH_OPTIONS_HOST, t.host)
        ssh_options_set(s, SSH_OPTIONS_PORT, &port)
        ssh_options_set(s, SSH_OPTIONS_USER, t.user)
        ssh_options_set(s, SSH_OPTIONS_TIMEOUT, &timeout)
        ssh_options_set(s, SSH_OPTIONS_KNOWNHOSTS, KnownHosts.path)
        if let key = t.keyPath { ssh_options_set(s, SSH_OPTIONS_ADD_IDENTITY, key) }
    }

    /// nil when the server's key is trusted; otherwise why not.
    private static func hostKeyFailure(_ s: ssh_session, _ t: SFTPTarget) -> Failure? {
        let fingerprint = KnownHosts.fingerprint(of: s, host: t.host, port: t.port)
        switch ssh_session_is_known_server(s) {
        case SSH_KNOWN_HOSTS_OK:
            return nil
        case SSH_KNOWN_HOSTS_UNKNOWN, SSH_KNOWN_HOSTS_NOT_FOUND:
            guard let fingerprint else { return Failure("Could not read the server's host key.", retryable: false) }
            return Failure("The server \(fingerprint.hostLabel) is not trusted yet.", hostKey: .unknown(fingerprint), retryable: false)
        case SSH_KNOWN_HOSTS_CHANGED, SSH_KNOWN_HOSTS_OTHER:
            guard let fingerprint else { return Failure("The server's host key changed.", retryable: false) }
            return Failure("The host key for \(fingerprint.hostLabel) has changed.", hostKey: .changed(fingerprint), retryable: false)
        default:
            return Failure("Host key check failed: \(sshError(s))", retryable: false)
        }
    }

    /// Connects, verifies the host key against the app's known hosts, and authenticates. Returns a reason on failure.
    static func connect(_ t: SFTPTarget) -> Result<SFTPSession, Failure> {
        guard let s = ssh_new() else { return .failure("ssh_new failed") }
        let session = SFTPSession()
        session.ssh = s
        configure(s, t)
        guard ssh_connect(s) == SSH_OK else { return .failure(Failure("connect: \(sshError(s))")) }
        if let failure = hostKeyFailure(s, t) { return .failure(failure) }
        let authenticated: Bool
        if let password = t.password {
            authenticated = ssh_userauth_password(s, nil, password) == Int32(SSH_AUTH_SUCCESS.rawValue)
        } else {
            authenticated = ssh_userauth_publickey_auto(s, nil, t.passphrase) == Int32(SSH_AUTH_SUCCESS.rawValue)
        }
        guard authenticated else { return .failure(Failure("authentication failed: \(sshError(s))", retryable: false)) }
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

    /// Lists a directory, resolving symlinks so linked folders show as folders.
    func list(_ path: String) -> Result<[RemoteEntry], Failure> {
        guard let sftp, let ssh else { return .failure("session closed") }
        guard let dir = sftp_opendir(sftp, path) else {
            return .failure(Failure("list \(path): sftp error \(sftp_get_error(sftp)), \(SFTPSession.sshError(ssh))"))
        }
        defer { sftp_closedir(dir) }
        var entries: [RemoteEntry] = []
        while let attrs = sftp_readdir(sftp, dir) {
            defer { sftp_attributes_free(attrs) }
            let name = String(cString: attrs.pointee.name)
            if name == "." || name == ".." { continue }
            var type = attrs.pointee.type
            var size = attrs.pointee.size
            var mtime = attrs.pointee.mtime
            if type == UInt8(SSH_FILEXFER_TYPE_SYMLINK),
               let target = sftp_stat(sftp, (path.hasSuffix("/") ? path : path + "/") + name) {
                type = target.pointee.type; size = target.pointee.size; mtime = target.pointee.mtime
                sftp_attributes_free(target)
            }
            entries.append(RemoteEntry(name: name, isDirectory: type == UInt8(SSH_FILEXFER_TYPE_DIRECTORY), size: size,
                                       modified: mtime == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(mtime))))
        }
        if sftp_dir_eof(dir) == 0 { broken = true; return .failure(Failure("list \(path): read interrupted")) }
        return .success(entries)
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
public final class SFTPSessionPool {
    let target: SFTPTarget
    private let slots = DispatchSemaphore(value: 3)
    private let lock = NSLock()
    private var idle: [SFTPSession] = []

    private let attempts: Int

    public init(_ target: SFTPTarget, attempts: Int = 3) { self.target = target; self.attempts = attempts }

    /// Runs `body` with exclusive use of a session; the session returns to the pool unless `broken`.
    func withSession<T>(_ body: (SFTPSession) -> T) -> Result<T, Failure> {
        slots.wait()
        defer { slots.signal() }
        lock.lock(); let reused = idle.popLast(); lock.unlock()
        var session = reused
        var lastError: Failure = "no attempts"
        attempts: for attempt in 0..<attempts where session == nil {
            switch SFTPSession.connect(target) {
            case .success(let s): session = s
            case .failure(let e):
                lastError = e
                if !e.retryable { break attempts }
                log("\(e.description) (attempt \(attempt + 1)/\(attempts))")
                Thread.sleep(forTimeInterval: 0.5 * Double(attempt + 1))
            }
        }
        guard let session else { return .failure(lastError) }
        let result = body(session)
        if !session.broken { lock.lock(); idle.append(session); lock.unlock() }
        return .success(result)
    }
}

public final class SFTPProxy {
    private let pool: SFTPSessionPool
    private let token = UUID().uuidString
    private let listener: NWListener
    private let workers = DispatchQueue(label: "proxy.workers", attributes: .concurrent)
    public private(set) var port: UInt16 = 0

    public convenience init?(target: SFTPTarget) { self.init(pool: SFTPSessionPool(target)) }

    public init?(pool: SFTPSessionPool) {
        self.pool = pool
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

    /// Loopback URL for a remote file. The random token keeps other local processes from reading the server through the proxy.
    /// Connects and authenticates once so host-key and credential problems surface before playback starts.
    public func preflight() async -> Failure? {
        let pool = pool
        return await Task.detached {
            switch pool.withSession({ _ in () }) {
            case .failure(let e): return e
            case .success: return nil
            }
        }.value
    }

    public func url(for remotePath: String) -> String {
        let encoded = remotePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remotePath
        return "http://127.0.0.1:\(port)/\(token)\(encoded.hasPrefix("/") ? encoded : "/" + encoded)"
    }

    /// Extracts the remote path from the request line, or nil if the token is missing.
    private func remotePath(in head: String) -> String? {
        let parts = head.prefix(while: { $0 != "\r" && $0 != "\n" }).split(separator: " ")
        guard parts.count >= 2, parts[1].hasPrefix("/\(token)/") else { return nil }
        return String(parts[1].dropFirst(token.count + 1)).removingPercentEncoding
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
        guard let path = remotePath(in: head) else {
            send(conn, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            return
        }
        let outcome: Result<String?, Failure> = pool.withSession { session in
            switch session.open(path) {
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
