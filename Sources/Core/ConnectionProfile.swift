import Foundation

/// A saved server. Passwords and key passphrases are not stored here; see `SecretStore`.
public struct ConnectionProfile: Codable, Identifiable, Equatable, Sendable {
    public enum Auth: Codable, Equatable, Sendable {
        case password
        case key(path: String)
    }

    public var id: UUID
    public var label: String
    public var host: String
    public var port: Int
    public var username: String
    public var auth: Auth
    public var defaultDirectory: String?

    public init(id: UUID = UUID(), label: String, host: String, port: Int = 22, username: String,
                auth: Auth, defaultDirectory: String? = nil) {
        self.id = id
        self.label = label
        self.host = host
        self.port = port
        self.username = username
        self.auth = auth
        self.defaultDirectory = defaultDirectory
    }

    /// `sftp://user@host[:port]/path`, never containing credentials. The path is not percent-encoded.
    public func url(path: String? = nil) -> String {
        let remote = path ?? defaultDirectory ?? "/"
        let hostPort = port == 22 ? host : "\(host):\(port)"
        return "sftp://\(username)@\(hostPort)\(remote.hasPrefix("/") ? remote : "/" + remote)"
    }

    /// What is wrong with the profile, or nil if it can be saved and used.
    public var validationError: String? {
        if host.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter a host name." }
        if username.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter a user name." }
        if !(1...65535).contains(port) { return "Port must be between 1 and 65535." }
        if case .key(let path) = auth, path.trimmingCharacters(in: .whitespaces).isEmpty { return "Choose a key file." }
        return nil
    }

    /// Connection settings for `path`; `secret` is the password, or the key passphrase for key auth.
    public func target(path: String? = nil, secret: String?) -> SFTPTarget {
        let remote = path ?? defaultDirectory ?? "/"
        let secret = (secret?.isEmpty ?? true) ? nil : secret
        switch auth {
        case .password:
            return SFTPTarget(host: host, port: port, user: username, path: remote, password: secret)
        case .key(let keyPath):
            return SFTPTarget(host: host, port: port, user: username, path: remote,
                              keyPath: (keyPath as NSString).expandingTildeInPath, passphrase: secret)
        }
    }
}
