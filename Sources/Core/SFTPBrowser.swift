import Foundation

/// Lists remote directories through the shared session pool.
public final class SFTPBrowser: @unchecked Sendable {
    private let pool: SFTPSessionPool

    public init(pool: SFTPSessionPool) { self.pool = pool }

    public func list(_ path: String) async -> Result<[RemoteEntry], Failure> {
        let pool = pool
        return await Task.detached {
            switch pool.withSession({ $0.list(path) }) {
            case .failure(let e): return .failure(e)
            case .success(let r): return r
            }
        }.value
    }
}
