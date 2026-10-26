import Foundation

/// Saved servers as JSON in `UserDefaults`; secrets go to the `SecretStore`.
public final class ProfileStore {
    private let defaults: UserDefaults
    private let secrets: SecretStore
    private let key: String

    public init(defaults: UserDefaults = .standard, secrets: SecretStore, key: String = "sftp_profiles") {
        self.defaults = defaults
        self.secrets = secrets
        self.key = key
    }

    public func all() -> [ConnectionProfile] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ConnectionProfile].self, from: data)) ?? []
    }

    public func secret(for profile: ConnectionProfile) -> String? { secrets.secret(for: profile.id) }

    /// Adds or replaces by id. Pass `secret: nil` to leave the stored secret untouched, "" to clear it.
    public func save(_ profile: ConnectionProfile, secret: String? = nil) {
        var profiles = all()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        write(profiles)
        if let secret { secrets.setSecret(secret, for: profile.id) }
    }

    public func delete(_ profile: ConnectionProfile) {
        write(all().filter { $0.id != profile.id })
        secrets.setSecret(nil, for: profile.id)
    }

    private func write(_ profiles: [ConnectionProfile]) {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: key)
    }
}
