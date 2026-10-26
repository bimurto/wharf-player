import Foundation
import CLibSSH

public struct HostKeyFingerprint: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let keyType: String
    /// `SHA256:` followed by base64, as shown by `ssh-keygen -l`.
    public let sha256: String

    public var hostLabel: String { port == 22 ? host : "\(host):\(port)" }
}

public enum HostKeyIssue: Equatable, Sendable {
    /// First connection to this server: ask the user before trusting it.
    case unknown(HostKeyFingerprint)
    /// The server presented a different key than the one saved: refuse.
    case changed(HostKeyFingerprint)
}

/// App-owned known-hosts file with trust-on-first-use. The user's `~/.ssh/known_hosts` is never read or written.
public enum KnownHosts {
    public static var path: String = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("SFTP Media Player/known_hosts").path
    }()

    static func fingerprint(of session: ssh_session, host: String, port: Int) -> HostKeyFingerprint? {
        var key: ssh_key?
        guard ssh_get_server_publickey(session, &key) == SSH_OK, let key else { return nil }
        defer { ssh_key_free(key) }
        var hash: UnsafeMutablePointer<UInt8>?
        var length = 0
        guard ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &length) == 0, let hashPtr = hash else { return nil }
        defer { ssh_clean_pubkey_hash(&hash) }
        guard let text = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hashPtr, length) else { return nil }
        defer { ssh_string_free_char(text) }
        let type = ssh_key_type_to_char(ssh_key_type(key)).map { String(cString: $0) } ?? "unknown"
        return HostKeyFingerprint(host: host, port: port, keyType: type, sha256: String(cString: text))
    }

    /// Saves the server's key after the user approved `approved`. Refuses if the server now presents a different key.
    public static func trust(_ approved: HostKeyFingerprint, target: SFTPTarget) -> Result<Void, Failure> {
        guard let s = ssh_new() else { return .failure("ssh_new failed") }
        defer { ssh_disconnect(s); ssh_free(s) }
        SFTPSession.configure(s, target)
        guard ssh_connect(s) == SSH_OK else {
            return .failure(Failure("connect: \(String(cString: ssh_get_error(UnsafeMutableRawPointer(s))))"))
        }
        guard fingerprint(of: s, host: target.host, port: target.port)?.sha256 == approved.sha256 else {
            return .failure("The server key changed while confirming, so it was not trusted.")
        }
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        guard ssh_session_update_known_hosts(s) == SSH_OK else {
            return .failure(Failure("Could not save the host key to \(path)."))
        }
        return .success(())
    }

    /// Removes the saved key for a server so the next connection asks again.
    public static func forget(host: String, port: Int) {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        try? removing(host: host, port: port, from: contents).write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func removing(host: String, port: Int, from contents: String) -> String {
        let pattern = (port == 22 ? host : "[\(host)]:\(port)").lowercased()
        let kept = contents.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            guard let field = line.split(separator: " ").first else { return true }
            return !field.lowercased().split(separator: ",").contains { $0 == pattern }
        }
        return kept.joined(separator: "\n")
    }
}
