public struct ASRTextSnapshot: Equatable, Sendable {
    public let committed: String
    public let tentative: String
    public let revision: Int
    public let inputReceivedMilliseconds: Int64
    public let audioCommittedMilliseconds: Int64
    public let bufferedMilliseconds: Int64

    public init(
        committed: String,
        tentative: String,
        revision: Int,
        inputReceivedMilliseconds: Int64,
        audioCommittedMilliseconds: Int64,
        bufferedMilliseconds: Int64
    ) {
        self.committed = committed
        self.tentative = tentative
        self.revision = revision
        self.inputReceivedMilliseconds = inputReceivedMilliseconds
        self.audioCommittedMilliseconds = audioCommittedMilliseconds
        self.bufferedMilliseconds = bufferedMilliseconds
    }
}
