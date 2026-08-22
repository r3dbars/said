import Foundation

public final class ResumableModelDownloader: NSObject, ModelDownloading, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var fileHandle: FileHandle?
    private var partialURL: URL?
    private var startingOffset: Int64 = 0
    private var receivedBytes: Int64 = 0
    private var expectedSize: Int64 = 0
    private var progress: (@Sendable (Int64, Int64) -> Void)?
    private var responseFailure: Error?
    private var session: URLSession?
    private let sessionConfiguration: URLSessionConfiguration

    public override convenience init() {
        self.init(configuration: .ephemeral)
    }

    public init(configuration: URLSessionConfiguration) {
        sessionConfiguration = configuration
        super.init()
    }

    public func download(
        from remoteURL: URL,
        to partialURL: URL,
        expectedSize: Int64,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        try FileManager.default.createDirectory(
            at: partialURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var offset = Self.fileSize(at: partialURL)
        if offset > expectedSize {
            try? FileManager.default.removeItem(at: partialURL)
            offset = 0
        }
        if !FileManager.default.fileExists(atPath: partialURL.path) {
            FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        }

        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if offset > 0 { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let queue = OperationQueue()
                queue.name = "app.said.model.download"
                queue.maxConcurrentOperationCount = 1
                let configuration = sessionConfiguration
                configuration.waitsForConnectivity = true
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 60 * 60 * 6
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
                lock.withLock {
                    self.continuation = continuation
                    self.partialURL = partialURL
                    self.startingOffset = offset
                    self.receivedBytes = offset
                    self.expectedSize = expectedSize
                    self.progress = progress
                    self.responseFailure = nil
                    self.session = session
                }
                progress(offset, expectedSize)
                session.dataTask(with: request).resume()
            }
        } onCancel: {
            self.lock.withLock { self.session?.invalidateAndCancel() }
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func finish(_ result: Result<Void, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            let current = self.continuation
            self.continuation = nil
            try? fileHandle?.close()
            fileHandle = nil
            progress = nil
            session?.finishTasksAndInvalidate()
            session = nil
            return current
        }
        continuation?.resume(with: result)
    }
}

extension ResumableModelDownloader: URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse,
              let partialURL = lock.withLock({ self.partialURL })
        else {
            lock.withLock { responseFailure = ModelDownloadError.invalidResponse }
            completionHandler(.cancel)
            return
        }

        do {
            let offset = lock.withLock { startingOffset }
            if offset > 0, http.statusCode == 206 {
                let expectedPrefix = "bytes \(offset)-"
                guard http.value(forHTTPHeaderField: "Content-Range")?.hasPrefix(expectedPrefix) == true else {
                    throw ModelDownloadError.invalidRange
                }
            } else if http.statusCode == 200 {
                FileManager.default.createFile(atPath: partialURL.path, contents: nil)
                lock.withLock {
                    startingOffset = 0
                    receivedBytes = 0
                }
            } else {
                throw ModelDownloadError.httpStatus(http.statusCode)
            }

            let handle = try FileHandle(forWritingTo: partialURL)
            try handle.seekToEnd()
            lock.withLock { fileHandle = handle }
            completionHandler(.allow)
        } catch {
            lock.withLock { responseFailure = error }
            completionHandler(.cancel)
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        do {
            let update = try lock.withLock { () throws -> (Int64, Int64, (@Sendable (Int64, Int64) -> Void)?) in
                guard let fileHandle else { throw ModelDownloadError.fileUnavailable }
                try fileHandle.write(contentsOf: data)
                receivedBytes += Int64(data.count)
                guard receivedBytes <= expectedSize else { throw ModelDownloadError.tooLarge }
                return (receivedBytes, expectedSize, progress)
            }
            update.2?(update.0, update.1)
        } catch {
            lock.withLock { responseFailure = error }
            dataTask.cancel()
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let result: Result<Void, Error> = lock.withLock {
            if let responseFailure { return .failure(responseFailure) }
            if let error { return .failure(error) }
            guard receivedBytes == expectedSize else {
                return .failure(ModelDownloadError.sizeMismatch(receivedBytes, expectedSize))
            }
            return .success(())
        }
        finish(result)
    }
}

public enum ModelDownloadError: Error, Equatable {
    case invalidResponse
    case invalidRange
    case httpStatus(Int)
    case fileUnavailable
    case tooLarge
    case sizeMismatch(Int64, Int64)
}
