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
    private var blockBuffer: PCMBlockBuffer?
    private var normalizedBlockCount = 0
    private var asrRestartAttempts = 0
    private var performanceCounters = ASRPerformanceCounters()
    var onCaption: ((ASRTextSnapshot) -> Void)?
    var onCaptionReset: (() -> Void)?
    var onStarted: (() -> Void)?
    var onFailure: ((CaptureFailure) -> Void)?

    private static let maximumASRRestartAttempts = 1
    private static let audioBufferCapacity = 16 // 2.56 seconds at 160 ms per block.

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
                let inputBuffer = beginFeedLoop(recognizer: recognizer)
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
                            if inputBuffer.enqueue(block) == .overflow {
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
                onStarted?()
            } catch is CancellationError {
                await teardownResources(finalState: .idle)
            } catch let failure as CaptureFailure {
                SaidLogger.capture.error(
                    "System-audio capture failed with safe code \(failure.rawValue, privacy: .public)"
                )
                await teardownResources(finalState: .failed(failure))
                onFailure?(failure)
            } catch {
                SaidLogger.capture.error("Caption pipeline failed before capture")
                await teardownResources(finalState: .failed(.unavailable))
                onFailure?(.unavailable)
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
        let activeFeedTask = feedTask
        activeFeedTask?.cancel()
        feedTask = nil
        blockBuffer?.finish()
        blockBuffer = nil
        normalizedBlockCount = 0
        await capture.stop()
        await activeFeedTask?.value
        await recognizer?.resetStream()
        recognizer = nil
        audioPipeline.reset()
        logPerformanceReceipt()
        performanceCounters = ASRPerformanceCounters()
        asrRestartAttempts = 0
        model.audioLevel = 0
        model.captureState = finalState
    }

    private func beginFeedLoop(
        recognizer: ParakeetUnifiedASR
    ) -> PCMBlockBuffer {
        blockBuffer?.finish()
        feedTask?.cancel()
        let buffer = PCMBlockBuffer(capacity: Self.audioBufferCapacity)
        blockBuffer = buffer
        feedTask = Task { [weak self] in
            var consumedBlockCount = 0
            let clock = ContinuousClock()
            while let block = await buffer.next() {
                guard !Task.isCancelled else { return }
                do {
                    consumedBlockCount += 1
                    if consumedBlockCount == 1 {
                        SaidLogger.asr.info("Recognizer received first normalized block")
                    }
                    let startedAt = clock.now
                    if let snapshot = try await recognizer.feed(block) {
                        self?.recordFeedDuration(startedAt.duration(to: clock.now))
                        SaidLogger.asr.info(
                            "Caption revision \(snapshot.revision, privacy: .public), committed characters \(snapshot.committed.count, privacy: .public), tentative characters \(snapshot.tentative.count, privacy: .public)"
                        )
                        self?.onCaption?(snapshot)
                    } else {
                        self?.recordFeedDuration(startedAt.duration(to: clock.now))
                    }
                } catch {
                    guard let self, await self.restartASRIfAllowed(recognizer) else {
                        SaidLogger.asr.error("Local recognizer feed failed after bounded recovery")
                        self?.failPipeline(.unavailable)
                        return
                    }
                }
            }
        }
        return buffer
    }

    private func restartASRIfAllowed(_ recognizer: ParakeetUnifiedASR) async -> Bool {
        guard asrRestartAttempts < Self.maximumASRRestartAttempts else { return false }
        asrRestartAttempts += 1
        model.captureState = .recovering(attempt: asrRestartAttempts)
        SaidLogger.asr.error(
            "Restarting local recognizer after recoverable feed failure; attempt \(self.asrRestartAttempts, privacy: .public)"
        )
        await recognizer.resetStream()
        do {
            try await recognizer.startStream()
            onCaptionReset?()
            model.captureState = .capturing
            return true
        } catch {
            return false
        }
    }

    private func recordFeedDuration(_ duration: Duration) {
        let receipt = performanceCounters.record(feedDuration: duration)
        if duration > .milliseconds(160) {
            SaidLogger.asr.notice(
                "Recognizer feed exceeded realtime block budget; slow feeds \(receipt.slowerThanRealtimeCount, privacy: .public)"
            )
        }
    }

    private func logPerformanceReceipt() {
        let receipt = performanceCounters.snapshot
        guard receipt.feedCount > 0 else { return }
        SaidLogger.asr.info(
            "Recognizer receipt: feeds \(receipt.feedCount, privacy: .public), average ms \(Int(receipt.averageFeedMilliseconds.rounded()), privacy: .public), maximum ms \(Int(receipt.maximumFeedMilliseconds.rounded()), privacy: .public), slower than realtime \(receipt.slowerThanRealtimeCount, privacy: .public)"
        )
    }

    private func failPipeline(_ failure: CaptureFailure) {
        guard !isFailure(model.captureState) else { return }
        statePollTask?.cancel()
        statePollTask = nil
        model.captureState = .failed(failure)
        onFailure?(failure)
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
