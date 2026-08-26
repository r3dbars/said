import Foundation
import SaidCore
import TranscribeCpp

public enum ParakeetASRError: Error, Sendable {
    case modelMissing
    case metalUnavailable
    case streamingUnavailable
    case bufferedExtensionUnavailable
    case streamNotStarted
    case committedPrefixMutation
}

public actor ParakeetUnifiedASR: StreamingASREngine {
    private let modelPath: String
    private var model: Model?
    private var session: Session?
    private var stream: TranscribeCpp.Stream?
    private var prefixRevisionGate = ASRPrefixRevisionGate()

    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    public func loadModel() async throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw ParakeetASRError.modelMissing
        }
        let loaded = try Model(path: modelPath, options: ModelOptions(backend: .metal))
        let device = try loaded.device
        guard device.kind == "metal" else { throw ParakeetASRError.metalUnavailable }
        guard loaded.capabilities.supportsStreaming else {
            throw ParakeetASRError.streamingUnavailable
        }
        let family = Self.familyOptions
        guard loaded.accepts(family) else {
            throw ParakeetASRError.bufferedExtensionUnavailable
        }
        model = loaded
        session = try loaded.session()
    }

    public func startStream() async throws {
        guard let session else { throw ParakeetASRError.modelMissing }
        stream?.reset()
        stream = try session.stream(
            RunOptions(language: "en"),
            StreamOptions(
                commitPolicy: .stablePrefix,
                stablePrefixAgreementN: 3,
                family: Self.familyOptions
            )
        )
        prefixRevisionGate.reset()
    }

    public func feed(_ block: PCMBlock) async throws -> ASRTextSnapshot? {
        guard let stream else { throw ParakeetASRError.streamNotStarted }
        let update = try stream.feed(block.samples)
        guard prefixRevisionGate.shouldEmit(
            resultChanged: update.resultChanged,
            revision: update.revision
        ) else { return nil }
        let text = stream.text
        do {
            try prefixRevisionGate.commit(text.committed, revision: update.revision)
        } catch {
            stream.reset()
            throw error
        }
        return ASRTextSnapshot(
            committed: text.committed,
            tentative: text.tentative,
            revision: Int(update.revision),
            inputReceivedMilliseconds: update.inputReceivedMs,
            audioCommittedMilliseconds: update.audioCommittedMs,
            bufferedMilliseconds: update.bufferedMs
        )
    }

    public func resetStream() async {
        stream?.reset()
        stream = nil
        prefixRevisionGate.reset()
    }

    public func unloadModel() async {
        await resetStream()
        session = nil
        model = nil
    }

    private static var familyOptions: StreamExtension {
        .parakeetBuffered(
            ParakeetBufferedStreamOptions(leftMs: 5_600, chunkMs: 160, rightMs: 160)
        )
    }
}
