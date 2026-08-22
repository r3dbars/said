@preconcurrency import AVFoundation
import AudioToolbox
import Foundation
import SaidCore

/// Captures outgoing Mac audio with a Core Audio process tap. This API is
/// governed by macOS's "System Audio Recording Only" permission and never
/// provides screen pixels or microphone samples.
@available(macOS 26.0, *)
public final class CoreAudioSystemAudioCapture: SystemAudioCapturing, @unchecked Sendable {
    public var state: CaptureState { lock.withLock { internalState } }

    private let lock = NSLock()
    private let ioQueue = DispatchQueue(label: "app.said.capture.core-audio", qos: .userInitiated)
    private let watchdogQueue = DispatchQueue(label: "app.said.capture.watchdog", qos: .utility)

    private var internalState: CaptureState = .idle
    private var generation: UInt64 = 0
    private var processTapID = AudioObjectID.saidUnknown
    private var aggregateDeviceID = AudioObjectID.saidUnknown
    private var deviceProcID: AudioDeviceIOProcID?
    private var bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var receivedFirstBuffer = false
    private var lastBufferUptime = 0.0
    private var recoveryAttempts = 0
    private var recoveryInFlight = false
    private var watchdog: DispatchSourceTimer?

    private static let firstBufferTimeout: Duration = .seconds(5)
    private static let stallSeconds = 4.0
    private static let maximumRecoveryAttempts = 1

    public init() {}

    public func start(
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) async throws {
        await stop()
        let captureGeneration = lock.withLock { () -> UInt64 in
            generation &+= 1
            internalState = .preparing
            bufferHandler = onBuffer
            receivedFirstBuffer = false
            lastBufferUptime = ProcessInfo.processInfo.systemUptime
            recoveryAttempts = 0
            return generation
        }

        do {
            try setupAndStart(generation: captureGeneration)
            try await waitForFirstBuffer(generation: captureGeneration)
            let valid = lock.withLock {
                guard generation == captureGeneration, receivedFirstBuffer else { return false }
                internalState = .capturing
                return true
            }
            guard valid else { throw CaptureFailure.startTimedOut }
            startWatchdog(generation: captureGeneration)
        } catch {
            teardownResources()
            let failure = classify(error)
            lock.withLock {
                if generation == captureGeneration { internalState = .failed(failure) }
            }
            throw failure
        }
    }

    public func stop() async {
        lock.withLock {
            generation &+= 1
            internalState = .stopping
            bufferHandler = nil
            receivedFirstBuffer = false
            recoveryInFlight = false
            recoveryAttempts = 0
        }
        stopWatchdog()
        teardownResources()
        lock.withLock { internalState = .idle }
    }

    private func setupAndStart(generation captureGeneration: UInt64) throws {
        let outputDevice = try AudioObjectID.saidDefaultSystemOutputDevice()
        guard outputDevice.saidIsValid else { throw CoreAudioCaptureError.invalidOutputDevice }
        let outputUID = try outputDevice.saidDeviceUID()

        let ownProcess = try? AudioObjectID.saidProcessObject(for: getpid())
        let excludedProcesses = ownProcess.map { [$0] } ?? []
        let tapDescription = CATapDescription(
            stereoGlobalTapButExcludeProcesses: excludedProcesses
        )
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted
        tapDescription.isPrivate = true

        var tapID = AudioObjectID.saidUnknown
        var status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard status == noErr else { throw CoreAudioCaptureError.createTap(status) }
        processTapID = tapID

        var streamDescription = try tapID.saidTapFormat()
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw CoreAudioCaptureError.invalidFormat
        }

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Said System Audio",
            kAudioAggregateDeviceUIDKey: "app.said.capture.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
            ]],
        ]

        var aggregateID = AudioObjectID.saidUnknown
        status = AudioHardwareCreateAggregateDevice(
            aggregateDescription as CFDictionary,
            &aggregateID
        )
        guard status == noErr else {
            throw CoreAudioCaptureError.createAggregateDevice(status)
        }
        aggregateDeviceID = aggregateID

        lock.withLock {
            guard generation == captureGeneration else { return }
            internalState = .starting
        }

        status = AudioDeviceCreateIOProcIDWithBlock(
            &deviceProcID,
            aggregateID,
            ioQueue
        ) { [weak self] _, inputData, _, _, _ in
            guard let self,
                  let borrowed = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: inputData,
                    deallocator: nil
                  ),
                  borrowed.frameLength > 0,
                  let owned = Self.copyBuffer(borrowed)
            else { return }
            self.accept(owned, generation: captureGeneration)
        }
        guard status == noErr else { throw CoreAudioCaptureError.createIOProc(status) }

        status = AudioDeviceStart(aggregateID, deviceProcID)
        guard status == noErr else { throw CoreAudioCaptureError.startDevice(status) }
    }

    private static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let destination = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else { return nil }
        destination.frameLength = source.frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }
        for index in sourceBuffers.indices {
            guard let sourceData = sourceBuffers[index].mData,
                  let destinationData = destinationBuffers[index].mData
            else { return nil }
            let byteCount = min(
                Int(sourceBuffers[index].mDataByteSize),
                Int(destinationBuffers[index].mDataByteSize)
            )
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffers[index].mDataByteSize = UInt32(byteCount)
        }
        return destination
    }

    private func accept(_ buffer: AVAudioPCMBuffer, generation captureGeneration: UInt64) {
        let handler: (@Sendable (AVAudioPCMBuffer) -> Void)? = lock.withLock {
            guard generation == captureGeneration,
                  internalState == .starting
                    || internalState == .capturing
                    || isRecovering(internalState)
            else { return nil }
            receivedFirstBuffer = true
            lastBufferUptime = ProcessInfo.processInfo.systemUptime
            if isRecovering(internalState) {
                internalState = .capturing
                recoveryInFlight = false
            }
            return bufferHandler
        }
        handler?(buffer)
    }

    private func waitForFirstBuffer(generation captureGeneration: UInt64) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.firstBufferTimeout)
        while clock.now < deadline {
            let status = lock.withLock { (generation == captureGeneration, receivedFirstBuffer) }
            guard status.0 else { throw CancellationError() }
            if status.1 { return }
            try await clock.sleep(for: .milliseconds(50))
        }
        throw CaptureFailure.startTimedOut
    }

    private func startWatchdog(generation captureGeneration: UInt64) {
        stopWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let stalled = self.lock.withLock {
                self.generation == captureGeneration
                    && self.internalState == .capturing
                    && self.receivedFirstBuffer
                    && ProcessInfo.processInfo.systemUptime - self.lastBufferUptime > Self.stallSeconds
            }
            if stalled { self.recover(generation: captureGeneration) }
        }
        lock.withLock { watchdog = timer }
        timer.resume()
    }

    private func stopWatchdog() {
        let timer = lock.withLock {
            let current = watchdog
            watchdog = nil
            return current
        }
        timer?.cancel()
    }

    private func recover(generation captureGeneration: UInt64) {
        let shouldRecover = lock.withLock {
            guard generation == captureGeneration,
                  !recoveryInFlight,
                  recoveryAttempts < Self.maximumRecoveryAttempts,
                  bufferHandler != nil
            else {
                if generation == captureGeneration { internalState = .failed(.stalled) }
                return false
            }
            recoveryInFlight = true
            recoveryAttempts += 1
            internalState = .recovering(attempt: recoveryAttempts)
            receivedFirstBuffer = false
            return true
        }
        guard shouldRecover else { return }

        ioQueue.async { [weak self] in
            guard let self else { return }
            self.teardownResources()
            Thread.sleep(forTimeInterval: 0.15)
            do {
                try self.setupAndStart(generation: captureGeneration)
            } catch {
                self.lock.withLock {
                    if self.generation == captureGeneration {
                        self.internalState = .failed(self.classify(error))
                        self.recoveryInFlight = false
                    }
                }
            }
        }
    }

    private func teardownResources() {
        let resources = lock.withLock { () -> (AudioObjectID, AudioDeviceIOProcID?, AudioObjectID) in
            let result = (aggregateDeviceID, deviceProcID, processTapID)
            aggregateDeviceID = .saidUnknown
            deviceProcID = nil
            processTapID = .saidUnknown
            return result
        }
        if resources.0.saidIsValid {
            _ = AudioDeviceStop(resources.0, resources.1)
            if let ioProc = resources.1 {
                _ = AudioDeviceDestroyIOProcID(resources.0, ioProc)
            }
            _ = AudioHardwareDestroyAggregateDevice(resources.0)
        }
        if resources.2.saidIsValid {
            _ = AudioHardwareDestroyProcessTap(resources.2)
        }
    }

    private func isRecovering(_ state: CaptureState) -> Bool {
        if case .recovering = state { return true }
        return false
    }

    private func classify(_ error: Error) -> CaptureFailure {
        if let failure = error as? CaptureFailure { return failure }
        let status: OSStatus?
        switch error {
        case CoreAudioCaptureError.property(let value),
             CoreAudioCaptureError.createTap(let value),
             CoreAudioCaptureError.createAggregateDevice(let value),
             CoreAudioCaptureError.createIOProc(let value),
             CoreAudioCaptureError.startDevice(let value):
            status = value
        default:
            status = nil
        }
        if status == kAudioDevicePermissionsError
            || status == kAudioComponentErr_NotPermitted {
            return .permissionDenied
        }
        return .unavailable
    }
}
