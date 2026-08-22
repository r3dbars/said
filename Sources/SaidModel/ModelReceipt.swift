import Foundation

public struct ModelReceipt: Codable, Equatable, Sendable {
    public let repository: String
    public let revision: String
    public let filename: String
    public let sizeBytes: Int64
    public let sha256: String
    public let installedAt: Date

    public init(manifest: ModelManifest, installedAt: Date = Date()) {
        repository = manifest.repository
        revision = manifest.revision
        filename = manifest.filename
        sizeBytes = manifest.sizeBytes
        sha256 = manifest.sha256
        self.installedAt = installedAt
    }
}
