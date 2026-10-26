import Foundation
import Security

/// Stores one secret (password or key passphrase) per profile.
public protocol SecretStore: AnyObject {
    func secret(for id: UUID) -> String?
    func setSecret(_ secret: String?, for id: UUID)
}

public final class KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "com.bimurto.sftp-media-player") { self.service = service }

    private func query(_ id: UUID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: id.uuidString]
    }

    public func secret(for id: UUID) -> String? {
        var q = query(id)
        q[kSecReturnData] = true
        q[kSecMatchLimit] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setSecret(_ secret: String?, for id: UUID) {
        guard let secret, !secret.isEmpty else { SecItemDelete(query(id) as CFDictionary); return }
        let data = Data(secret.utf8)
        let update = SecItemUpdate(query(id) as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = query(id)
            add[kSecValueData] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// For tests and previews.
public final class InMemorySecretStore: SecretStore {
    private var secrets: [UUID: String] = [:]
    public init() {}
    public func secret(for id: UUID) -> String? { secrets[id] }
    public func setSecret(_ secret: String?, for id: UUID) {
        if let secret, !secret.isEmpty { secrets[id] = secret } else { secrets[id] = nil }
    }
}
