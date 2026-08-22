import Foundation

public struct ModelManifest: Codable, Equatable, Sendable {
    public let repository: String
    public let revision: String
    public let filename: String
    public let sizeBytes: Int64
    public let sha256: String

    public init(
        repository: String,
        revision: String,
        filename: String,
        sizeBytes: Int64,
        sha256: String
    ) {
        self.repository = repository
        self.revision = revision
        self.filename = filename
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
    }

    public var downloadURL: URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(filename)")!
    }

    public static let saidEnglishQ8 = ModelManifest(
        repository: "handy-computer/parakeet-unified-en-0.6b-gguf",
        revision: "7e948f21b7bdbac698d3318db9d350f1096f3b6c",
        filename: "parakeet-unified-en-0.6b-Q8_0.gguf",
        sizeBytes: 731_357_568,
        sha256: "4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795"
    )
}
