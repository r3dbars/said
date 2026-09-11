import AVFoundation
import XCTest
@testable import SaidCapture

final class CoreAudioTapBufferTests: XCTestCase {
    func testCopiesStereoTapFramesIntoOwnedMemory() throws {
        for interleaved in [true, false] {
            let format = try XCTUnwrap(AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                channels: 2, interleaved: interleaved
            ))
            let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
            input.frameLength = 512
            let buffers = UnsafeMutableAudioBufferListPointer(input.mutableAudioBufferList)
            for buffer in buffers {
                let values = try XCTUnwrap(buffer.mData).assumingMemoryBound(to: Float.self)
                values.update(repeating: 0.25, count: Int(buffer.mDataByteSize) / 4)
            }
            let owned = try XCTUnwrap(CoreAudioTapBuffer.copy(input.audioBufferList, format: format))
            for buffer in buffers { memset(buffer.mData!, 0, Int(buffer.mDataByteSize)) }
            XCTAssertEqual(owned.frameLength, 512)
            XCTAssertEqual(owned.format, format)
            let samples = try XCTUnwrap(owned.floatChannelData)[0]
            XCTAssertEqual(samples[0], 0.25)
            XCTAssertEqual(samples[511], 0.25)
            XCTAssertFalse(try AudioNormalizer().process(owned).isEmpty)
        }
    }

    func testRejectsAdditionalHardwareInputWithoutReadingIt() throws {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
            channels: 2, interleaved: true
        ))
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        // Reproduce a display's mono input followed by the stereo process tap.
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 2048, mData: nil)
        list[1] = AudioBuffer(mNumberChannels: 2, mDataByteSize: 4096, mData: nil)
        XCTAssertNil(CoreAudioTapBuffer.copy(list.unsafePointer, format: format))
    }

    func testRejectsWrongChannelsAndPartialFrames() throws {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
            channels: 2, interleaved: true
        ))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        input.frameLength = 512
        let list = AudioBufferList.allocate(maximumBuffers: 1)
        defer { free(list.unsafeMutablePointer) }
        list[0] = input.audioBufferList.pointee.mBuffers
        list[0].mNumberChannels = 1
        XCTAssertNil(CoreAudioTapBuffer.copy(list.unsafePointer, format: format))
        list[0].mNumberChannels = 2
        list[0].mDataByteSize -= 1
        XCTAssertNil(CoreAudioTapBuffer.copy(list.unsafePointer, format: format))
    }
}
