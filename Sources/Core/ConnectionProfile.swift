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
}
