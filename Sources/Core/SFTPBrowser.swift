import Foundation

/// Something that can list a remote directory; faked in tests.
public protocol DirectoryLister: Sendable {
    func list(_ path: String) async -> Result<Listing, Failure>
}

/// Lists remote directories through the shared session pool.
public final class SFTPBrowser: DirectoryLister, @unchecked Sendable {
    private let pool: SFTPSessionPool

    public init(pool: SFTPSessionPool) { self.pool = pool }

    public func list(_ path: String) async -> Result<Listing, Failure> {
        let pool = pool
        return await Task.detached {
            switch pool.withSession({ $0.listing(path) }) {
            case .failure(let e): return .failure(e)
            case .success(let r): return r
            }
        }.value
    }
}
