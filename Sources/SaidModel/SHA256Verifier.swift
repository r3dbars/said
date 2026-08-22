import CryptoKit
import Foundation

public enum SHA256Verifier {
    public static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 4 * 1_024 * 1_024)
            guard let data, !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func matches(_ url: URL, manifest: ModelManifest) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value == manifest.sizeBytes,
              let digest = try? digest(of: url)
        else { return false }
        return digest == manifest.sha256
    }
}
