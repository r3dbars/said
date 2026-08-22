import Foundation

enum AppPaths {
    static let modelFilename = "parakeet-unified-en-0.6b-Q8_0.gguf"

    static var installedModelURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Said/Models/parakeet-unified-en-0.6b", isDirectory: true)
            .appendingPathComponent(modelFilename)
    }

    static var developmentModelURL: URL {
        Bundle.main.bundleURL
            .deletingLastPathComponent() // dist
            .deletingLastPathComponent() // repository
            .appendingPathComponent("Artifacts/Models", isDirectory: true)
            .appendingPathComponent(modelFilename)
    }

    static var availableModelURL: URL? {
        let candidates = [installedModelURL, developmentModelURL]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
