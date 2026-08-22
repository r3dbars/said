import Foundation

public enum PCMBlockEnqueueResult: Equatable, Sendable {
    case delivered
    case buffered(depth: Int)
    case overflow
    case closed
}

/// A small, synchronous producer / asynchronous consumer buffer for live PCM.
///
/// The Core Audio path cannot await the recognizer. This buffer preserves block
/// order without allowing audio to accumulate indefinitely. An overflow closes
/// the buffer immediately so Said never continues captioning stale audio after
/// silently dropping part of the stream.
public final class PCMBlockBuffer: @unchecked Sendable {
    public let capacity: Int

    private let lock = NSLock()
    private var blocks: [PCMBlock] = []
    private var waiter: CheckedContinuation<PCMBlock?, Never>?
    private var isClosed = false

    public init(capacity: Int = 8) {
        precondition(capacity > 0)
        self.capacity = capacity
        blocks.reserveCapacity(capacity)
    }

    public func enqueue(_ block: PCMBlock) -> PCMBlockEnqueueResult {
        var consumer: CheckedContinuation<PCMBlock?, Never>?
        let result = lock.withLock { () -> PCMBlockEnqueueResult in
            guard !isClosed else { return .closed }
            if let waiter {
                self.waiter = nil
                consumer = waiter
                return .delivered
            }
            guard blocks.count < capacity else {
                blocks.removeAll(keepingCapacity: false)
                isClosed = true
                return .overflow
            }
            blocks.append(block)
            return .buffered(depth: blocks.count)
        }
        consumer?.resume(returning: block)
        return result
    }

    public func next() async -> PCMBlock? {
        await withCheckedContinuation { continuation in
            var immediate: PCMBlock??
            lock.withLock {
                if !blocks.isEmpty {
                    immediate = blocks.removeFirst()
                } else if isClosed {
                    immediate = .some(nil)
                } else {
                    precondition(waiter == nil, "PCMBlockBuffer supports one consumer")
                    waiter = continuation
                }
            }
            if let immediate { continuation.resume(returning: immediate) }
        }
    }

    public func finish() {
        let consumer = lock.withLock { () -> CheckedContinuation<PCMBlock?, Never>? in
            guard !isClosed || waiter != nil else { return nil }
            isClosed = true
            blocks.removeAll(keepingCapacity: false)
            let consumer = waiter
            waiter = nil
            return consumer
        }
        consumer?.resume(returning: nil)
    }
}
