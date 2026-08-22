@preconcurrency import AVFoundation
import SaidCore

public final class AudioNormalizer: @unchecked Sendable {
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?

    public init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }

    public func process(_ input: AVAudioPCMBuffer) throws -> [Float] {
        guard let monoInput = downmixToMono(input) else { return [] }
        if sourceFormat != monoInput.format || converter == nil {
            sourceFormat = monoInput.format
            converter = AVAudioConverter(from: monoInput.format, to: targetFormat)
        }
        guard let converter else { return [] }

        let ratio = targetFormat.sampleRate / monoInput.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(monoInput.frameLength) * ratio)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return []
        }
        let provider = ConverterInput(buffer: monoInput)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            provider.next(status: inputStatus)
        }
        if let conversionError { throw conversionError }
        guard status == .haveData || status == .inputRanDry else { return [] }
        guard let channel = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

    private func downmixToMono(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard input.format.commonFormat == .pcmFormatFloat32,
              let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: input.format.sampleRate,
                channels: 1,
                interleaved: false
              ),
              let output = AVAudioPCMBuffer(
                pcmFormat: monoFormat,
                frameCapacity: input.frameLength
              ),
              let destination = output.floatChannelData?[0]
        else { return nil }

        output.frameLength = input.frameLength
        let frameCount = Int(input.frameLength)
        let channelCount = Int(input.format.channelCount)
        guard channelCount > 0 else { return nil }

        if input.format.isInterleaved {
            let buffers = UnsafeMutableAudioBufferListPointer(input.mutableAudioBufferList)
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return nil
            }
            for frame in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += data[frame * channelCount + channel]
                }
                destination[frame] = sum / Float(channelCount)
            }
        } else {
            guard let channels = input.floatChannelData else { return nil }
            for frame in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount { sum += channels[channel][frame] }
                destination[frame] = sum / Float(channelCount)
            }
        }
        return output
    }

    public func reset() {
        converter?.reset()
        converter = nil
        sourceFormat = nil
    }
}

private final class ConverterInput: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var consumed = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(
        status: UnsafeMutablePointer<AVAudioConverterInputStatus>
    ) -> AVAudioBuffer? {
        guard !consumed else {
            status.pointee = .noDataNow
            return nil
        }
        consumed = true
        status.pointee = .haveData
        return buffer
    }
}
