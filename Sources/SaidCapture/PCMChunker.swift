import SaidCore

public struct PCMChunker: Sendable {
    public let blockSize: Int
    private var remainder: [Float] = []

    public init(blockSize: Int = 2_560) {
        precondition(blockSize > 0)
        self.blockSize = blockSize
    }

    public mutating func append(_ samples: [Float]) -> [PCMBlock] {
        remainder.append(contentsOf: samples)
        var blocks: [PCMBlock] = []
        var consumed = 0
        while remainder.count - consumed >= blockSize {
            blocks.append(PCMBlock(samples: Array(remainder[consumed..<(consumed + blockSize)])))
            consumed += blockSize
        }
        if consumed > 0 { remainder.removeFirst(consumed) }
        return blocks
    }

    public mutating func reset() {
        remainder.removeAll(keepingCapacity: false)
    }
}
