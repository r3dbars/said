public struct ASRPrefixRevisionGate: Equatable, Sendable {
    public private(set) var previousCommitted: String
    public private(set) var lastRevision: Int32

    public init(previousCommitted: String = "", lastRevision: Int32 = -1) {
        self.previousCommitted = previousCommitted
        self.lastRevision = lastRevision
    }

    public func shouldEmit(resultChanged: Bool, revision: Int32) -> Bool {
        resultChanged && revision != lastRevision
    }

    public mutating func commit(_ committed: String, revision: Int32) throws {
        guard committed.hasPrefix(previousCommitted) else {
            throw ParakeetASRError.committedPrefixMutation
        }
        previousCommitted = committed
        lastRevision = revision
    }

    public mutating func reset() {
        previousCommitted = ""
        lastRevision = -1
    }
}
