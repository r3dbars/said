@preconcurrency import AVFoundation
import OSLog
import SaidCore

public final class AudioBlockPipeline: @unchecked Sendable {
    private static let logger = Logger(subsystem: "app.said.Said", category: "audio")
    private let queue = DispatchQueue(label: "app.said.audio.normalize", qos: .userInitiated)
    private let normalizer = AudioNormalizer()
    private var chunker = PCMChunker()
    private var didLogInput = false
    private var didLogOutput = false

    public init() {}

    public func process(
        _ buffer: AVAudioPCMBuffer,
        onBlock: @escaping @Sendable (PCMBlock) -> Void,
        onError: @escaping @Sendable () -> Void
    ) {
        queue.async { [self] in
            do {
                if !didLogInput {
                    didLogInput = true
                    Self.logger.info(
                        "Normalizer received first buffer: frames \(buffer.frameLength, privacy: .public), rate \(buffer.format.sampleRate, privacy: .public), channels \(buffer.format.channelCount, privacy: .public)"
                    )
                }
                let samples = try normalizer.process(buffer)
                if !didLogOutput, !samples.isEmpty {
                    didLogOutput = true
                    Self.logger.info(
                        "Normalizer produced first sample batch: samples \(samples.count, privacy: .public)"
                    )
                }
                for block in chunker.append(samples) { onBlock(block) }
            } catch {
                onError()
            }
        }
    }

    public func reset() {
        queue.async { [self] in
            normalizer.reset()
            chunker.reset()
            didLogInput = false
            didLogOutput = false
        }
    }
}
