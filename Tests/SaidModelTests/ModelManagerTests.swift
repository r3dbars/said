import CryptoKit
import Foundation
import XCTest
import SaidCore
@testable import SaidModel

final class ModelManagerTests: XCTestCase {
    func testPinnedManifestUsesImmutableRevisionURL() {
        let manifest = ModelManifest.saidEnglishQ8
        XCTAssertTrue(manifest.downloadURL.absoluteString.contains(manifest.revision))
        XCTAssertFalse(manifest.downloadURL.absoluteString.contains("main"))
        XCTAssertEqual(manifest.sizeBytes, 731_357_568)
    }

    func testStreamingSHA256VerifierMatchesKnownData() throws {
        let fixture = Data("small verified model fixture".utf8)
        let manifest = manifest(for: fixture)
        let url = temporaryRoot().appendingPathComponent("fixture.gguf")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fixture.write(to: url)

        XCTAssertEqual(try SHA256Verifier.digest(of: url), manifest.sha256)
        XCTAssertTrue(SHA256Verifier.matches(url, manifest: manifest))
    }

    func testInstallResumesPartialVerifiesAndWritesReceipt() async throws {
        let fixture = Data("small verified model fixture".utf8)
        let manifest = manifest(for: fixture)
        let root = temporaryRoot()
        let store = ModelStore(root: root)
        try FileManager.default.createDirectory(
            at: store.downloadDirectory,
            withIntermediateDirectories: true
        )
        let prefix = fixture.prefix(7)
        try Data(prefix).write(to: store.partialURL(for: manifest))
        let downloader = FixtureDownloader(payload: fixture, expectedStartingSize: Int64(prefix.count))
        let manager = ModelManager(manifest: manifest, store: store, downloader: downloader)

        let installed = try await manager.install { _ in }
        let isValid = await manager.validateInstalledModel()

        XCTAssertEqual(try Data(contentsOf: installed), fixture)
        XCTAssertTrue(isValid)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.receiptURL(for: manifest).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.partialURL(for: manifest).path))
    }

    func testCorruptReplacementNeverDestroysExistingValidModel() async throws {
        let valid = Data("existing valid model".utf8)
        let corrupt = Data("corrupt replacement!".utf8)
        XCTAssertEqual(valid.count, corrupt.count)
        let manifest = manifest(for: valid)
        let root = temporaryRoot()
        let store = ModelStore(root: root)
        try FileManager.default.createDirectory(at: store.modelDirectory, withIntermediateDirectories: true)
        try valid.write(to: store.modelURL(for: manifest))
        let manager = ModelManager(
            manifest: manifest,
            store: store,
            downloader: FixtureDownloader(payload: corrupt)
        )

        do {
            _ = try await manager.install(force: true) { _ in }
            XCTFail("Expected verification failure")
        } catch {
            XCTAssertEqual(error as? ModelFailure, .verificationFailed)
        }

        XCTAssertEqual(try Data(contentsOf: store.modelURL(for: manifest)), valid)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.partialURL(for: manifest).path))
    }

    func testCompletedVerifiedPartialInstallsWithoutAnotherRequest() async throws {
        let fixture = Data("already finished partial".utf8)
        let manifest = manifest(for: fixture)
        let store = ModelStore(root: temporaryRoot())
        try FileManager.default.createDirectory(at: store.downloadDirectory, withIntermediateDirectories: true)
        try fixture.write(to: store.partialURL(for: manifest))
        let manager = ModelManager(
            manifest: manifest,
            store: store,
            downloader: FailingDownloader()
        )

        let installed = try await manager.install { _ in }

        XCTAssertEqual(try Data(contentsOf: installed), fixture)
    }

    private func manifest(for data: Data) -> ModelManifest {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ModelManifest(
            repository: "example/model",
            revision: String(repeating: "a", count: 40),
            filename: "fixture.gguf",
            sizeBytes: Int64(data.count),
            sha256: digest
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SaidModelTests-\(UUID().uuidString)", isDirectory: true)
    }
}

private struct FailingDownloader: ModelDownloading {
    func download(
        from remoteURL: URL,
        to partialURL: URL,
        expectedSize: Int64,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        XCTFail("A completed verified partial must not be downloaded again")
        throw URLError(.badServerResponse)
    }
}

private struct FixtureDownloader: ModelDownloading {
    let payload: Data
    var expectedStartingSize: Int64?

    init(payload: Data, expectedStartingSize: Int64? = nil) {
        self.payload = payload
        self.expectedStartingSize = expectedStartingSize
    }

    func download(
        from remoteURL: URL,
        to partialURL: URL,
        expectedSize: Int64,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        try FileManager.default.createDirectory(
            at: partialURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let attributes = try? FileManager.default.attributesOfItem(atPath: partialURL.path)
        let existing = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        if let expectedStartingSize {
            XCTAssertEqual(existing, expectedStartingSize)
        }
        if !FileManager.default.fileExists(atPath: partialURL.path) {
            FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partialURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: payload.dropFirst(Int(existing)))
        try handle.close()
        XCTAssertEqual(try Data(contentsOf: partialURL), payload)
        progress(Int64(payload.count), expectedSize)
    }
}
