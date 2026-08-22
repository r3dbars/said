public enum CaptureState: Equatable, Sendable {
    case idle
    case preparing
    case starting
    case capturing
    case recovering(attempt: Int)
    case stopping
    case failed(CaptureFailure)
}

public enum CaptureFailure: String, Error, Equatable, Sendable {
    case permissionDenied
    case noDisplay
    case startTimedOut
    case stalled
    case stoppedUnexpectedly
    case unavailable
}
