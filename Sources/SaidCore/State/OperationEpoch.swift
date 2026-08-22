/// Owns asynchronous work with a monotonically advancing generation.
///
/// A caller captures the value returned by `begin()`. Any later begin or
/// invalidation supersedes that value, allowing late callbacks and task
/// continuations to prove they no longer own the current operation.
public struct OperationEpoch: Sendable {
    private var current: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func begin() -> UInt64 {
        current &+= 1
        return current
    }

    public mutating func invalidate() {
        current &+= 1
    }

    public func owns(_ candidate: UInt64) -> Bool {
        candidate == current
    }

    public func acceptsCaptureBuffer(
        from candidate: UInt64,
        while state: CaptureState
    ) -> Bool {
        guard owns(candidate) else { return false }
        switch state {
        case .starting, .capturing, .recovering:
            return true
        case .idle, .preparing, .stopping, .failed:
            return false
        }
    }
}
