@preconcurrency import AVFoundation

/// Validate the tap's complete layout before touching sample memory. In
/// particular, never interpret additional hardware input streams as tap audio.
enum CoreAudioTapBuffer {
    static func copy(
        _ input: UnsafePointer<AudioBufferList>, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let expectedBuffers = format.isInterleaved ? 1 : Int(format.channelCount)
        let channelsPerBuffer = format.isInterleaved ? format.channelCount : 1
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        guard expectedBuffers > 0, buffers.count == expectedBuffers, bytesPerFrame > 0,
              let first = buffers.first, first.mDataByteSize > 0,
              first.mDataByteSize.isMultiple(of: bytesPerFrame)
        else { return nil }
        let byteCount = first.mDataByteSize
        guard buffers.allSatisfy({
            $0.mNumberChannels == channelsPerBuffer && $0.mData != nil
                && $0.mDataByteSize == byteCount
        }) else { return nil }

        let frameCount = byteCount / bytesPerFrame
        guard let destination = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        destination.frameLength = frameCount
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard destinationBuffers.count == buffers.count else { return nil }
        for index in buffers.indices {
            guard let sourceData = buffers[index].mData,
                  let destinationData = destinationBuffers[index].mData,
                  destinationBuffers[index].mDataByteSize == byteCount
            else { return nil }
            memcpy(destinationData, sourceData, Int(byteCount))
        }
        return destination
    }
}
