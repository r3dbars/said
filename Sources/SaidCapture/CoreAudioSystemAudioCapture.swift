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

    private struct CaptureResources {
        let generation: UInt64
        let processTapID: AudioObjectID
        let aggregateDeviceID: AudioObjectID
        let deviceProcID: AudioDeviceIOProcID?
        let routeDeviceID: AudioObjectID
    }

    private var internalState: CaptureState = .idle
    private var operationEpoch = OperationEpoch()
    private var resources: CaptureResources?
    private var outputDeviceListener: AudioObjectPropertyListenerBlock?
    private var bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var receivedFirstBuffer = false
    private var lastBufferUptime = 0.0
    private var lastOutputDeviceChangeUptime = 0.0
    private var recoveryAttempts = 0
    private var recoveryInFlight = false
    private var watchdog: DispatchSourceTimer?

    private static let stallSeconds = 4.0
    private static let outputDeviceChangeDebounceSeconds = 0.3
    private static let maximumRecoveryAttempts = 1

    public init() {}

    public func start(
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) async throws {
        await stop()
        let captureGeneration = lock.withLock { () -> UInt64 in
            let generation = operationEpoch.begin()
            internalState = .preparing
            bufferHandler = onBuffer
            receivedFirstBuffer = false
            lastBufferUptime = ProcessInfo.processInfo.systemUptime
            lastOutputDeviceChangeUptime = 0
            recoveryAttempts = 0
            return generation
        }

        do {
            let mayStart = lock.withLock { () -> Bool in
                guard operationEpoch.owns(captureGeneration) else { return false }
                internalState = .starting
                return true
            }
            guard mayStart else { throw CancellationError() }
            try setupAndStart(generation: captureGeneration)
            try installOutputDeviceListener(generation: captureGeneration)
            let valid = lock.withLock {
                guard operationEpoch.owns(captureGeneration) else { return false }
                internalState = .capturing
                return true
            }
            guard valid else { throw CancellationError() }
            startWatchdog(generation: captureGeneration)
        } catch {
            let isCurrentGeneration = lock.withLock {
                operationEpoch.owns(captureGeneration)
            }
            guard isCurrentGeneration else { throw CancellationError() }
            teardownResources(generation: captureGeneration)
            let failure = classify(error)
            lock.withLock {
                if operationEpoch.owns(captureGeneration) {
                    internalState = .failed(failure)
                }
            }
            throw failure
        }
    }

    public func stop() async {
        lock.withLock {
            operationEpoch.invalidate()
            internalState = .stopping
            bufferHandler = nil
            receivedFirstBuffer = false
            recoveryInFlight = false
            recoveryAttempts = 0
        }
        stopWatchdog()
        removeOutputDeviceListener()
        teardownResources()
        lock.withLock { internalState = .idle }
    }

    private func setupAndStart(generation captureGeneration: UInt64) throws {
        guard lock.withLock({ operationEpoch.owns(captureGeneration) }) else {
            throw CancellationError()
        }
        let outputDevice = try AudioObjectID.saidDefaultSystemOutputDevice()
        guard outputDevice.saidIsValid else { throw CoreAudioCaptureError.invalidOutputDevice }
        let outputUID = try outputDevice.saidDeviceUID()
        let routeDevice = try AudioObjectID.saidDefaultOutputDevice()
        guard routeDevice.saidIsValid else { throw CoreAudioCaptureError.invalidOutputDevice }

        let ownProcess = try? AudioObjectID.saidProcessObject(for: getpid())
        let excludedProcesses = ownProcess.map { [$0] } ?? []
        let tapDescription = CATapDescription(
            stereoGlobalTapButExcludeProcesses: excludedProcesses
        )
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted
        tapDescription.isPrivate = true

        var tapID = AudioObjectID.saidUnknown
        var aggregateID = AudioObjectID.saidUnknown
        var procID: AudioDeviceIOProcID?
        var installed = false
        defer {
            if !installed {
                Self.destroyResources(
                    aggregateDeviceID: aggregateID,
                    deviceProcID: procID,
                    processTapID: tapID
                )
            }
        }

        var status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard status == noErr else { throw CoreAudioCaptureError.createTap(status) }

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

        status = AudioHardwareCreateAggregateDevice(
            aggregateDescription as CFDictionary,
            &aggregateID
        )
        guard status == noErr else {
            throw CoreAudioCaptureError.createAggregateDevice(status)
        }

        status = AudioDeviceCreateIOProcIDWithBlock(
            &procID,
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

        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else { throw CoreAudioCaptureError.startDevice(status) }

        let accepted = lock.withLock { () -> Bool in
            guard operationEpoch.owns(captureGeneration),
                  resources == nil
            else { return false }
            resources = CaptureResources(
                generation: captureGeneration,
                processTapID: tapID,
                aggregateDeviceID: aggregateID,
                deviceProcID: procID,
                routeDeviceID: routeDevice
            )
            return true
        }
        guard accepted else { throw CancellationError() }
        installed = true
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
            guard operationEpoch.acceptsCaptureBuffer(
                from: captureGeneration,
                while: internalState
            )
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

    private func startWatchdog(generation captureGeneration: UInt64) {
        stopWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let currentOutputDevice = try? AudioObjectID.saidDefaultOutputDevice()
            let shouldRecover = self.lock.withLock {
                guard self.operationEpoch.owns(captureGeneration),
                      self.internalState == .capturing
                else { return false }
                return CaptureWatchdogPolicy.shouldRecover(
                    hasReceivedFirstBuffer: self.receivedFirstBuffer,
                    secondsSinceLastBuffer: ProcessInfo.processInfo.systemUptime
                        - self.lastBufferUptime,
                    stallSeconds: Self.stallSeconds,
                    outputDeviceChanged: currentOutputDevice?.saidIsValid == true
                        && currentOutputDevice != self.resources?.routeDeviceID
                )
            }
            if shouldRecover { self.recover(generation: captureGeneration) }
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

    private func installOutputDeviceListener(generation captureGeneration: UInt64) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleOutputDeviceChange(generation: captureGeneration)
        }
        let status = AudioObjectAddPropertyListenerBlock(
            .saidSystem,
            &address,
            ioQueue,
            listener
        )
        guard status == noErr else {
            throw CoreAudioCaptureError.addPropertyListener(status)
        }
        let accepted = lock.withLock { () -> Bool in
            guard operationEpoch.owns(captureGeneration),
                  outputDeviceListener == nil
            else { return false }
            outputDeviceListener = listener
            return true
        }
        guard accepted else {
            _ = AudioObjectRemovePropertyListenerBlock(
                .saidSystem,
                &address,
                ioQueue,
                listener
            )
            throw CancellationError()
        }
    }

    private func removeOutputDeviceListener() {
        let listener = lock.withLock { () -> AudioObjectPropertyListenerBlock? in
            let current = outputDeviceListener
            outputDeviceListener = nil
            return current
        }
        guard let listener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectRemovePropertyListenerBlock(
            .saidSystem,
            &address,
            ioQueue,
            listener
        )
    }

    private func handleOutputDeviceChange(generation captureGeneration: UInt64) {
        let now = ProcessInfo.processInfo.systemUptime
        let shouldRecover = lock.withLock { () -> Bool in
            guard operationEpoch.owns(captureGeneration),
                  internalState == .capturing,
                  now - lastOutputDeviceChangeUptime
                    >= Self.outputDeviceChangeDebounceSeconds
            else { return false }
            lastOutputDeviceChangeUptime = now
            return true
        }
        if shouldRecover { recover(generation: captureGeneration) }
    }

    private func recover(generation captureGeneration: UInt64) {
        let shouldRecover = lock.withLock {
            guard operationEpoch.owns(captureGeneration),
                  !recoveryInFlight,
                  recoveryAttempts < Self.maximumRecoveryAttempts,
                  bufferHandler != nil
            else {
                if operationEpoch.owns(captureGeneration) {
                    internalState = .failed(.stalled)
                }
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
            guard self.lock.withLock({
                self.operationEpoch.owns(captureGeneration) && self.recoveryInFlight
            }) else { return }
            self.teardownResources(generation: captureGeneration)
            Thread.sleep(forTimeInterval: 0.15)
            guard self.lock.withLock({
                self.operationEpoch.owns(captureGeneration) && self.recoveryInFlight
            }) else { return }
            do {
                try self.setupAndStart(generation: captureGeneration)
                self.lock.withLock {
                    if self.operationEpoch.owns(captureGeneration) {
                        self.internalState = .capturing
                        self.recoveryInFlight = false
                    }
                }
            } catch {
                self.lock.withLock {
                    if self.operationEpoch.owns(captureGeneration) {
                        self.internalState = .failed(self.classify(error))
                        self.recoveryInFlight = false
                    }
                }
            }
        }
    }

    private func teardownResources(generation expectedGeneration: UInt64? = nil) {
        let ownedResources = lock.withLock { () -> CaptureResources? in
            guard let current = resources,
                  expectedGeneration == nil || current.generation == expectedGeneration
            else { return nil }
            resources = nil
            return current
        }
        guard let ownedResources else { return }
        Self.destroyResources(
            aggregateDeviceID: ownedResources.aggregateDeviceID,
            deviceProcID: ownedResources.deviceProcID,
            processTapID: ownedResources.processTapID
        )
    }

    private static func destroyResources(
        aggregateDeviceID: AudioObjectID,
        deviceProcID: AudioDeviceIOProcID?,
        processTapID: AudioObjectID
    ) {
        if aggregateDeviceID.saidIsValid {
            _ = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if let deviceProcID {
                _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
            }
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        if processTapID.saidIsValid {
            _ = AudioHardwareDestroyProcessTap(processTapID)
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
             CoreAudioCaptureError.startDevice(let value),
             CoreAudioCaptureError.addPropertyListener(let value):
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
