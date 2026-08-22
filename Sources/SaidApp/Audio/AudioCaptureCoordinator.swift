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
    private var operationEpoch = OperationEpoch()
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
        let startEpoch = operationEpoch.begin()
        model.captureState = .preparing
        SaidLogger.capture.info("Starting system-audio caption pipeline")
        Task {
            let recognizer = ParakeetUnifiedASR(modelPath: modelURL.path)
            do {
                try await recognizer.loadModel()
                guard operationEpoch.owns(startEpoch) else {
                    await recognizer.unloadModel()
                    return
                }
                self.recognizer = recognizer
                SaidLogger.model.info("Loaded pinned model on Metal")
                try await recognizer.startStream()
                guard operationEpoch.owns(startEpoch) else {
                    await recognizer.unloadModel()
                    return
                }
                let inputBuffer = beginFeedLoop(
                    recognizer: recognizer,
                    operationEpoch: startEpoch
                )
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
                                    guard self.operationEpoch.owns(startEpoch) else { return }
                                    SaidLogger.audio.error("Audio block queue overflowed")
                                    self.failPipeline(.unavailable, operationEpoch: startEpoch)
                                }
                            }
                        },
                        onError: { [weak self] in
                            Task { @MainActor in
                                self?.failPipeline(.unavailable, operationEpoch: startEpoch)
                            }
                        }
                    )
                }
                guard operationEpoch.owns(startEpoch) else {
                    await recognizer.unloadModel()
                    return
                }
                model.captureState = .capturing
                SaidLogger.capture.info("System-audio tap started; awaiting playback buffers")
                beginStatePolling()
                onStarted?()
            } catch is CancellationError {
                await teardownResources(
                    finalState: .idle,
                    operationEpoch: startEpoch
                )
            } catch let failure as CaptureFailure {
                guard operationEpoch.owns(startEpoch) else {
                    await recognizer.unloadModel()
                    return
                }
                SaidLogger.capture.error(
                    "System-audio capture failed with safe code \(failure.rawValue, privacy: .public)"
                )
                await teardownResources(
                    finalState: .failed(failure),
                    operationEpoch: startEpoch
                )
                onFailure?(failure)
            } catch {
                guard operationEpoch.owns(startEpoch) else {
                    await recognizer.unloadModel()
                    return
                }
                SaidLogger.capture.error("Caption pipeline failed before capture")
                await teardownResources(
                    finalState: .failed(.unavailable),
                    operationEpoch: startEpoch
                )
                onFailure?(.unavailable)
            }
        }
    }

    func stop() {
        Task { await stopAndWait() }
    }

    func stopAndWait() async {
        let stopEpoch = operationEpoch.begin()
        SaidLogger.capture.info("Stopping system-audio caption pipeline")
        await teardownResources(finalState: .idle, operationEpoch: stopEpoch)
    }

    private func teardownResources(
        finalState: CaptureState,
        operationEpoch expectedEpoch: UInt64
    ) async {
        guard operationEpoch.owns(expectedEpoch) else { return }
        model.captureState = .stopping
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
        if operationEpoch.owns(expectedEpoch) {
            model.captureState = finalState
        }
    }

    private func beginFeedLoop(
        recognizer: ParakeetUnifiedASR,
        operationEpoch expectedEpoch: UInt64
    ) -> PCMBlockBuffer {
        blockBuffer?.finish()
        feedTask?.cancel()
        let buffer = PCMBlockBuffer(capacity: Self.audioBufferCapacity)
        blockBuffer = buffer
        feedTask = Task { [weak self] in
            var consumedBlockCount = 0
            let clock = ContinuousClock()
            while let block = await buffer.next() {
                guard !Task.isCancelled,
                      self?.operationEpoch.owns(expectedEpoch) == true
                else { return }
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
                    guard let self,
                          await self.restartASRIfAllowed(
                              recognizer,
                              operationEpoch: expectedEpoch
                          )
                    else {
                        SaidLogger.asr.error("Local recognizer feed failed after bounded recovery")
                        self?.failPipeline(.unavailable, operationEpoch: expectedEpoch)
                        return
                    }
                }
            }
        }
        return buffer
    }

    private func restartASRIfAllowed(
        _ recognizer: ParakeetUnifiedASR,
        operationEpoch expectedEpoch: UInt64
    ) async -> Bool {
        guard operationEpoch.owns(expectedEpoch),
              asrRestartAttempts < Self.maximumASRRestartAttempts
        else { return false }
        asrRestartAttempts += 1
        model.captureState = .recovering(attempt: asrRestartAttempts)
        SaidLogger.asr.error(
            "Restarting local recognizer after recoverable feed failure; attempt \(self.asrRestartAttempts, privacy: .public)"
        )
        await recognizer.resetStream()
        do {
            try await recognizer.startStream()
            guard operationEpoch.owns(expectedEpoch) else { return false }
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

    private func failPipeline(
        _ failure: CaptureFailure,
        operationEpoch expectedEpoch: UInt64
    ) {
        guard operationEpoch.owns(expectedEpoch),
              !isFailure(model.captureState)
        else { return }
        statePollTask?.cancel()
        statePollTask = nil
        model.captureState = .failed(failure)
        onFailure?(failure)
        Task { [weak self] in
            guard let self else { return }
            await teardownResources(
                finalState: .failed(failure),
                operationEpoch: expectedEpoch
            )
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
