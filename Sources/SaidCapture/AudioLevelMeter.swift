import Accelerate
import AVFoundation

public enum AudioLevelMeter {
    public static func normalizedLevel(for buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData,
              buffer.frameLength > 0,
              buffer.format.channelCount > 0
        else { return 0 }

        let count = vDSP_Length(buffer.frameLength)
        var combined: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var rms: Float = 0
            vDSP_rmsqv(channels[channel], 1, &rms, count)
            combined += rms
        }
        let average = combined / Float(buffer.format.channelCount)
        return min(max(Double(average) * 8, 0), 1)
    }
}
