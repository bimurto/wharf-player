import Foundation

public enum ConnectionTester {
    /// Connects once (no retries), authenticates, and lists `directory` (the home directory when nil).
    /// Success carries the number of entries found.
    public static func test(_ target: SFTPTarget, directory: String?) async -> Result<Int, Failure> {
        await Task.detached {
            switch SFTPSessionPool(target, attempts: 1).withSession({ $0.list(directory ?? ".") }) {
            case .failure(let e): return .failure(e)
            case .success(.failure(let e)): return .failure(e)
            case .success(.success(let entries)): return .success(entries.count)
            }
        }.value
    }
}
