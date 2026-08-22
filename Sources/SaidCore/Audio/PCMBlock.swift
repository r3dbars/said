public struct PCMBlock: Equatable, Sendable {
    public let samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
    }
}
