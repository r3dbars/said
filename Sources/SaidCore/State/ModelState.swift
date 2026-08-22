public enum ModelState: Equatable, Sendable {
    case checking
    case notDownloaded
    case downloading(receivedBytes: Int64, totalBytes: Int64)
    case verifying
    case ready
    case failed(ModelFailure)

    public var progress: Double? {
        guard case let .downloading(received, total) = self, total > 0 else { return nil }
        return min(1, max(0, Double(received) / Double(total)))
    }
}

public enum ModelFailure: String, Error, Equatable, Sendable {
    case downloadFailed
    case invalidResponse
    case sizeMismatch
    case verificationFailed
    case installationFailed
}
