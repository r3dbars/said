import Foundation

public struct ModelStore: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            self.root = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Said", isDirectory: true)
        }
    }

    public var modelDirectory: URL {
        root.appendingPathComponent("Models/parakeet-unified-en-0.6b", isDirectory: true)
    }

    public var downloadDirectory: URL {
        root.appendingPathComponent("Downloads", isDirectory: true)
    }

    public func modelURL(for manifest: ModelManifest) -> URL {
        modelDirectory.appendingPathComponent(manifest.filename)
    }

    public func receiptURL(for manifest: ModelManifest) -> URL {
        modelDirectory.appendingPathComponent("receipt.json")
    }

    public func partialURL(for manifest: ModelManifest) -> URL {
        downloadDirectory.appendingPathComponent(manifest.filename + ".partial")
    }
}
