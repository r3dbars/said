import AVFoundation
import XCTest
@testable import SaidCapture

final class AudioNormalizerTests: XCTestCase {
    func testInterleavedStereoDownsamplesIntoContinuousMono() throws {
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 2,
                interleaved: true
            )
        )
        let normalizer = AudioNormalizer()
        var output: [Float] = []

        for _ in 0..<30 {
            let buffer = try XCTUnwrap(
                AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)
            )
            buffer.frameLength = 512
            let samples = buffer.audioBufferList.pointee.mBuffers.mData!
                .assumingMemoryBound(to: Float.self)
            for frame in 0..<512 {
                samples[frame * 2] = 0.5
                samples[frame * 2 + 1] = -0.25
            }
            output.append(contentsOf: try normalizer.process(buffer))
        }

        XCTAssertGreaterThan(output.count, 4_500)
        XCTAssertLessThan(output.count, 5_500)
        XCTAssertEqual(output[100], 0.125, accuracy: 0.01)
    }
}
