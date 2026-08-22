import Foundation

public protocol ModelDownloading: Sendable {
    func download(
        from remoteURL: URL,
        to partialURL: URL,
        expectedSize: Int64,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws
}
