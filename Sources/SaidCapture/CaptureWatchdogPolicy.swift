import Foundation

enum CaptureWatchdogPolicy {
    static func shouldRecover(
        hasReceivedFirstBuffer: Bool,
        secondsSinceLastBuffer: TimeInterval,
        stallSeconds: TimeInterval,
        outputDeviceChanged: Bool
    ) -> Bool {
        if outputDeviceChanged { return true }
        guard hasReceivedFirstBuffer else { return false }
        return secondsSinceLastBuffer > stallSeconds
    }
}
