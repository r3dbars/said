import SaidCore

public protocol StreamingASREngine: Sendable {
    func loadModel() async throws
    func startStream() async throws
    func feed(_ block: PCMBlock) async throws -> ASRTextSnapshot?
    func resetStream() async
    func unloadModel() async
}
