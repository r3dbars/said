import AudioToolbox
import Foundation

extension AudioObjectID {
    static let saidSystem = AudioObjectID(kAudioObjectSystemObject)
    static let saidUnknown = AudioObjectID(kAudioObjectUnknown)

    var saidIsValid: Bool { self != .saidUnknown }

    static func saidDefaultSystemOutputDevice() throws -> AudioDeviceID {
        try saidSystem.saidRead(
            kAudioHardwarePropertyDefaultSystemOutputDevice,
            defaultValue: AudioDeviceID.saidUnknown
        )
    }

    static func saidDefaultOutputDevice() throws -> AudioDeviceID {
        try saidSystem.saidRead(
            kAudioHardwarePropertyDefaultOutputDevice,
            defaultValue: AudioDeviceID.saidUnknown
        )
    }

    static func saidProcessObject(for processID: pid_t) throws -> AudioObjectID {
        try saidSystem.saidRead(
            kAudioHardwarePropertyTranslatePIDToProcessObject,
            defaultValue: AudioObjectID.saidUnknown,
            qualifier: processID
        )
    }

    func saidDeviceUID() throws -> String {
        try saidRead(kAudioDevicePropertyDeviceUID, defaultValue: "" as CFString) as String
    }

    func saidTapFormat() throws -> AudioStreamBasicDescription {
        try saidRead(kAudioTapPropertyFormat, defaultValue: AudioStreamBasicDescription())
    }

    private func saidRead<T>(
        _ selector: AudioObjectPropertySelector,
        defaultValue: T
    ) throws -> T {
        try saidRead(
            AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            defaultValue: defaultValue,
            qualifierSize: 0,
            qualifierData: nil
        )
    }

    private func saidRead<T, Q>(
        _ selector: AudioObjectPropertySelector,
        defaultValue: T,
        qualifier: Q
    ) throws -> T {
        var mutableQualifier = qualifier
        return try withUnsafePointer(to: &mutableQualifier) { pointer in
            try saidRead(
                AudioObjectPropertyAddress(
                    mSelector: selector,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                ),
                defaultValue: defaultValue,
                qualifierSize: UInt32(MemoryLayout<Q>.size),
                qualifierData: pointer
            )
        }
    }

    private func saidRead<T>(
        _ originalAddress: AudioObjectPropertyAddress,
        defaultValue: T,
        qualifierSize: UInt32,
        qualifierData: UnsafeRawPointer?
    ) throws -> T {
        var address = originalAddress
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            self,
            &address,
            qualifierSize,
            qualifierData,
            &dataSize
        )
        guard status == noErr else { throw CoreAudioCaptureError.property(status) }

        var value = defaultValue
        status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(
                self,
                &address,
                qualifierSize,
                qualifierData,
                &dataSize,
                pointer
            )
        }
        guard status == noErr else { throw CoreAudioCaptureError.property(status) }
        return value
    }
}

enum CoreAudioCaptureError: Error {
    case property(OSStatus)
    case createTap(OSStatus)
    case createAggregateDevice(OSStatus)
    case createIOProc(OSStatus)
    case startDevice(OSStatus)
    case addPropertyListener(OSStatus)
    case invalidOutputDevice
    case invalidFormat
}
