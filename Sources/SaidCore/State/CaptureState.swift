public enum CaptureState: Equatable, Sendable {
    case idle
    case preparing
    case starting
    case capturing
    case recovering(attempt: Int)
    case stopping
    case failed(CaptureFailure)
}

public extension CaptureState {
    var shouldResumeAfterSystemWake: Bool {
        switch self {
        case .preparing, .starting, .capturing, .recovering:
            true
        case .idle, .stopping, .failed:
            false
        }
    }
}

public enum CaptureFailure: String, Error, Equatable, Sendable {
    case permissionDenied
    case noDisplay
    case stalled
    case stoppedUnexpectedly
    case unavailable
}
