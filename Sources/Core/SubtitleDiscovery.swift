import Foundation

/// Guards server subtitle discovery against stale results. Each video calls `begin()` for a token;
/// a result is delivered only while its token is still the newest. Discovery never selects a track.
public final class SubtitleDiscovery: @unchecked Sendable {
    public struct Token: Equatable, Sendable { fileprivate let generation: Int }

    private var generation = 0
    private let lock = NSLock()

    public init() {}

    /// Starts a new request; every earlier token becomes stale.
    public func begin() -> Token {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        return Token(generation: generation)
    }

    public func isCurrent(_ token: Token) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return token.generation == generation
    }

    /// The subtitles beside `videoPath`, or nil when a newer request began while listing.
    public func discover(_ token: Token, videoPath: String, lister: DirectoryLister) async -> [ExternalSubtitle]? {
        let found = await ExternalSubtitles.discover(videoPath: videoPath, lister: lister)
        return isCurrent(token) ? found : nil
    }
}
