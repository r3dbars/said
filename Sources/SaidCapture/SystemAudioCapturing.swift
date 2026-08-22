import AVFoundation
import SaidCore

public protocol SystemAudioCapturing: AnyObject, Sendable {
    var state: CaptureState { get }
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws
    func stop() async
}
