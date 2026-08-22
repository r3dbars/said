import Foundation
import XCTest
@testable import SaidModel

final class ResumableModelDownloaderTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testResumesFromExistingPartialWithValidatedRange() async throws {
        let payload = Data("abcdef".utf8)
        let partialURL = temporaryFileURL()
        try Data("abc".utf8).write(to: partialURL)
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=3-")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 206,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Range": "bytes 3-5/6"]
            )!
            return (response, Data("def".utf8))
        }

        let downloader = ResumableModelDownloader(configuration: stubConfiguration())
        try await downloader.download(
            from: URL(string: "https://example.invalid/model.gguf")!,
            to: partialURL,
            expectedSize: Int64(payload.count)
        ) { _, _ in }

        XCTAssertEqual(try Data(contentsOf: partialURL), payload)
    }

    func testServerIgnoringRangeRestartsPartialInsteadOfDuplicatingBytes() async throws {
        let payload = Data("abcdef".utf8)
        let partialURL = temporaryFileURL()
        try Data("abc".utf8).write(to: partialURL)
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=3-")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "6"]
            )!
            return (response, payload)
        }

        let downloader = ResumableModelDownloader(configuration: stubConfiguration())
        try await downloader.download(
            from: URL(string: "https://example.invalid/model.gguf")!,
            to: partialURL,
            expectedSize: Int64(payload.count)
        ) { _, _ in }

        XCTAssertEqual(try Data(contentsOf: partialURL), payload)
    }

    private func stubConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaidDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("model.gguf.partial")
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func setHandler(_ handler: Handler?) {
        lock.withLock { self.handler = handler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.handler }) else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
