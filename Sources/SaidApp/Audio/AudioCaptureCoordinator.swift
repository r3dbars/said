@preconcurrency import AVFoundation
import SaidASR
import SaidCapture
import SaidCore

@MainActor
final class AudioCaptureCoordinator {
    private let model: AppModel
    private let capture: CoreAudioSystemAudioCapture
    private let audioPipeline = AudioBlockPipeline()
    private var recognizer: ParakeetUnifiedASR?
    private var statePollTask: Task<Void, Never>?
    private var feedTask: Task<Void, Never>?
    private var blockContinuation: AsyncStream<PCMBlock>.Continuation?
    private var normalizedBlockCount = 0
    var onCaption: ((ASRTextSnapshot) -> Void)?

    init(model: AppModel) {
        self.model = model
        capture = CoreAudioSystemAudioCapture()
    }

    func start(modelURL: URL) {
        guard model.captureState == .idle || isFailure(model.captureState) else { return }
        model.captureState = .preparing
        SaidLogger.capture.info("Starting system-audio caption pipeline")
        Task {
            do {
                let recognizer = ParakeetUnifiedASR(modelPath: modelURL.path)
                self.recognizer = recognizer
                try await recognizer.loadModel()
                SaidLogger.model.info("Loaded pinned model on Metal")
                try await recognizer.startStream()
                let inputContinuation = beginFeedLoop(recognizer: recognizer)
                try await capture.start { [weak model] buffer in
                    let level = AudioLevelMeter.normalizedLevel(for: buffer)
                    Task { @MainActor in model?.audioLevel = level }
                    self.audioPipeline.process(
                        buffer,
                        onBlock: { [weak self] block in
                            guard let self else { return }
                            Task { @MainActor in
                                self.normalizedBlockCount += 1
                                if self.normalizedBlockCount == 1 {
                                    SaidLogger.audio.info("First normalized 16 kHz block produced")
                                }
                            }
                            let result = inputContinuation.yield(block)
                            if case .dropped = result {
                                Task { @MainActor in
                                    SaidLogger.audio.error("Audio block queue overflowed")
                                    self.failPipeline(.unavailable)
                                }
                            }
                        },
                        onError: { [weak self] in
                            Task { @MainActor in self?.failPipeline(.unavailable) }
                        }
                    )
                }
                model.captureState = .capturing
                SaidLogger.capture.info("System-audio tap started; awaiting playback buffers")
                beginStatePolling()
            } catch let failure as CaptureFailure {
                SaidLogger.capture.error(
                    "System-audio capture failed with safe code \(failure.rawValue, privacy: .public)"
                )
                await teardownResources(finalState: .failed(failure))
            } catch {
                SaidLogger.capture.error("Caption pipeline failed before capture")
                await teardownResources(finalState: .failed(.unavailable))
            }
        }
    }

    func stop() {
        Task { await stopAndWait() }
    }

    func stopAndWait() async {
        SaidLogger.capture.info("Stopping system-audio caption pipeline")
        await teardownResources(finalState: .idle)
    }

    private func teardownResources(finalState: CaptureState) async {
        statePollTask?.cancel()
        statePollTask = nil
        blockContinuation?.finish()
        blockContinuation = nil
        feedTask?.cancel()
        feedTask = nil
        normalizedBlockCount = 0
        await capture.stop()
        await recognizer?.resetStream()
        recognizer = nil
        audioPipeline.reset()
        model.audioLevel = 0
        model.captureState = finalState
    }

    private func beginFeedLoop(
        recognizer: ParakeetUnifiedASR
    ) -> AsyncStream<PCMBlock>.Continuation {
        blockContinuation?.finish()
        feedTask?.cancel()
        let (blocks, continuation) = AsyncStream.makeStream(
            of: PCMBlock.self,
            bufferingPolicy: .bufferingOldest(8)
        )
        blockContinuation = continuation
        feedTask = Task { [weak self] in
            var consumedBlockCount = 0
            for await block in blocks {
                guard !Task.isCancelled else { return }
                do {
                    consumedBlockCount += 1
                    if consumedBlockCount == 1 {
                        SaidLogger.asr.info("Recognizer received first normalized block")
                    }
                    if let snapshot = try await recognizer.feed(block) {
                        SaidLogger.asr.info(
                            "Caption revision \(snapshot.revision, privacy: .public), committed characters \(snapshot.committed.count, privacy: .public), tentative characters \(snapshot.tentative.count, privacy: .public)"
                        )
                        self?.onCaption?(snapshot)
                    }
                } catch {
                    SaidLogger.asr.error("Local recognizer feed failed")
                    self?.failPipeline(.unavailable)
                    return
                }
            }
        }
        return continuation
    }

    private func failPipeline(_ failure: CaptureFailure) {
        guard !isFailure(model.captureState) else { return }
        statePollTask?.cancel()
        statePollTask = nil
        model.captureState = .failed(failure)
        Task { [weak self] in
            guard let self else { return }
            await teardownResources(finalState: .failed(failure))
        }
    }

    private func beginStatePolling() {
        statePollTask?.cancel()
        statePollTask = Task {
            while !Task.isCancelled {
                model.captureState = capture.state
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func isFailure(_ state: CaptureState) -> Bool {
        if case .failed = state { return true }
        return false
    }
}
