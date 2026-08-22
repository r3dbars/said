import Foundation
import SaidCore

public actor ModelManager {
    public let manifest: ModelManifest
    public let store: ModelStore
    private let downloader: any ModelDownloading

    public init(
        manifest: ModelManifest = .saidEnglishQ8,
        store: ModelStore = ModelStore(),
        downloader: any ModelDownloading = ResumableModelDownloader()
    ) {
        self.manifest = manifest
        self.store = store
        self.downloader = downloader
    }

    public var installedModelURL: URL { store.modelURL(for: manifest) }

    public func validateInstalledModel() -> Bool {
        SHA256Verifier.matches(installedModelURL, manifest: manifest)
    }

    public func validateModel(at url: URL) -> Bool {
        SHA256Verifier.matches(url, manifest: manifest)
    }

    public func install(
        force: Bool = false,
        progress: @escaping @Sendable (ModelState) -> Void
    ) async throws -> URL {
        if !force, validateInstalledModel() {
            progress(.ready)
            return installedModelURL
        }

        let partialURL = store.partialURL(for: manifest)
        if !SHA256Verifier.matches(partialURL, manifest: manifest) {
            progress(.downloading(receivedBytes: Self.fileSize(at: partialURL), totalBytes: manifest.sizeBytes))
            do {
                try await downloader.download(
                    from: manifest.downloadURL,
                    to: partialURL,
                    expectedSize: manifest.sizeBytes
                ) { received, total in
                    progress(.downloading(receivedBytes: received, totalBytes: total))
                }
            } catch {
                progress(.failed(.downloadFailed))
                throw ModelFailure.downloadFailed
            }
        }

        progress(.verifying)
        guard SHA256Verifier.matches(partialURL, manifest: manifest) else {
            try? FileManager.default.removeItem(at: partialURL)
            progress(.failed(.verificationFailed))
            throw ModelFailure.verificationFailed
        }

        do {
            try FileManager.default.createDirectory(
                at: store.modelDirectory,
                withIntermediateDirectories: true
            )
            let finalURL = installedModelURL
            if FileManager.default.fileExists(atPath: finalURL.path) {
                _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: partialURL)
            } else {
                try FileManager.default.moveItem(at: partialURL, to: finalURL)
            }
            let receipt = ModelReceipt(manifest: manifest)
            let receiptData = try JSONEncoder().encode(receipt)
            try receiptData.write(to: store.receiptURL(for: manifest), options: .atomic)
            progress(.ready)
            return finalURL
        } catch {
            progress(.failed(.installationFailed))
            throw ModelFailure.installationFailed
        }
    }

    public func remove() throws {
        let fileManager = FileManager.default
        let urls = [
            installedModelURL,
            store.receiptURL(for: manifest),
            store.partialURL(for: manifest),
        ]
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
