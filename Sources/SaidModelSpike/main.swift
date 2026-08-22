import Foundation
import TranscribeCpp

private struct Configuration {
    var modelPath = "Artifacts/Models/parakeet-unified-en-0.6b-Q8_0.gguf"
    var audioPath = "Dependencies/transcribe.cpp/samples/jfk.wav"
    var leftMilliseconds: Int32 = 5_600
    var chunkMilliseconds: Int32 = 160
    var rightMilliseconds: Int32 = 160
    var feedBlockMilliseconds = 160
    var showText = false

    static func parse(_ arguments: [String]) throws -> Self {
        var result = Self()
        var index = 0
        func value(after flag: String) throws -> String {
            guard index + 1 < arguments.count else {
                throw SpikeError.usage("missing value after \(flag)")
            }
            index += 1
            return arguments[index]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--model": result.modelPath = try value(after: argument)
            case "--audio": result.audioPath = try value(after: argument)
            case "--left-ms": result.leftMilliseconds = try parseInteger(try value(after: argument), flag: argument)
            case "--chunk-ms": result.chunkMilliseconds = try parseInteger(try value(after: argument), flag: argument)
            case "--right-ms": result.rightMilliseconds = try parseInteger(try value(after: argument), flag: argument)
            case "--feed-ms": result.feedBlockMilliseconds = try parseInteger(try value(after: argument), flag: argument)
            case "--show-text": result.showText = true
            case "--help", "-h": throw SpikeError.help
            default: throw SpikeError.usage("unknown argument: \(argument)")
            }
            index += 1
        }

        guard result.feedBlockMilliseconds > 0 else {
            throw SpikeError.usage("--feed-ms must be positive")
        }
        return result
    }
}

private enum SpikeError: Error, CustomStringConvertible {
    case help
    case usage(String)
    case invalidFixture(String)
    case gate(String)

    var description: String {
        switch self {
        case .help: return Self.usageText
        case .usage(let message): return "\(message)\n\n\(Self.usageText)"
        case .invalidFixture(let message): return "invalid WAV fixture: \(message)"
        case .gate(let message): return "PR 0 gate failed: \(message)"
        }
    }

    static let usageText = """
    Usage: said-model-spike [options]
      --model PATH       Q8_0 GGUF path
      --audio PATH       16 kHz mono PCM16 WAV fixture
      --left-ms N        buffered left context (default: 5600)
      --chunk-ms N       buffered chunk (default: 160)
      --right-ms N       buffered right context (default: 160)
      --feed-ms N        PCM feed block (default: 160)
      --show-text        print fixture hypotheses as they change
    """
}

private func parseInteger<T: FixedWidthInteger>(_ value: String, flag: String) throws -> T {
    guard let parsed = T(value) else {
        throw SpikeError.usage("invalid integer for \(flag): \(value)")
    }
    return parsed
}

private struct WAVFixture {
    let samples: [Float]
    let durationMilliseconds: Int64
    let speechOnsetMilliseconds: Int64

    init(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count >= 44,
              String(bytes: data[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: data[8..<12], encoding: .ascii) == "WAVE"
        else { throw SpikeError.invalidFixture("missing RIFF/WAVE header") }

        func uint16(_ offset: Int) -> UInt16 {
            UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        }
        func uint32(_ offset: Int) -> UInt32 {
            UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
                | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
        }

        var format: (encoding: UInt16, channels: UInt16, sampleRate: UInt32, bits: UInt16)?
        var pcmRange: Range<Int>?
        var cursor = 12
        while cursor + 8 <= data.count {
            let identifier = String(bytes: data[cursor..<(cursor + 4)], encoding: .ascii) ?? ""
            let length = Int(uint32(cursor + 4))
            let start = cursor + 8
            let end = start + length
            guard end <= data.count else { throw SpikeError.invalidFixture("truncated \(identifier) chunk") }
            if identifier == "fmt ", length >= 16 {
                format = (uint16(start), uint16(start + 2), uint32(start + 4), uint16(start + 14))
            } else if identifier == "data" {
                pcmRange = start..<end
            }
            cursor = end + (length & 1)
        }

        guard let format else { throw SpikeError.invalidFixture("missing fmt chunk") }
        guard format.encoding == 1, format.channels == 1,
              format.sampleRate == 16_000, format.bits == 16
        else {
            throw SpikeError.invalidFixture(
                "expected PCM16 mono 16000 Hz; got encoding=\(format.encoding), channels=\(format.channels), rate=\(format.sampleRate), bits=\(format.bits)"
            )
        }
        guard let pcmRange else { throw SpikeError.invalidFixture("missing data chunk") }

        var decoded: [Float] = []
        decoded.reserveCapacity(pcmRange.count / 2)
        var sampleOffset = pcmRange.lowerBound
        while sampleOffset + 1 < pcmRange.upperBound {
            let raw = Int16(bitPattern: uint16(sampleOffset))
            decoded.append(Float(raw) / 32_768)
            sampleOffset += 2
        }
        samples = decoded
        durationMilliseconds = Int64(decoded.count) * 1_000 / 16_000
        speechOnsetMilliseconds = Self.detectSpeechOnset(in: decoded)
    }

    private static func detectSpeechOnset(in samples: [Float]) -> Int64 {
        let windowSamples = 320 // 20 ms at 16 kHz
        let threshold: Float = 0.01
        guard samples.count >= windowSamples else { return 0 }
        for start in stride(from: 0, through: samples.count - windowSamples, by: windowSamples) {
            let sumSquares = samples[start..<(start + windowSamples)].reduce(Float.zero) { partial, sample in
                partial + sample * sample
            }
            if sqrt(sumSquares / Float(windowSamples)) >= threshold {
                return Int64(start) * 1_000 / 16_000
            }
        }
        return 0
    }
}

private struct FeedReceipt: Codable {
    let index: Int
    let samples: Int
    let wallMilliseconds: Double
    let revision: Int32
    let inputReceivedMilliseconds: Int64
    let audioCommittedMilliseconds: Int64
    let bufferedMilliseconds: Int64
    let committedCharacters: Int
    let tentativeCharacters: Int
}

private struct SpikeReceipt: Codable {
    let runtimeCommit: String
    let backend: String
    let architecture: String
    let variant: String
    let device: String
    let modelLoadMilliseconds: Double
    let audioDurationMilliseconds: Int64
    let detectedSpeechOnsetMilliseconds: Int64
    let leftMilliseconds: Int32
    let chunkMilliseconds: Int32
    let rightMilliseconds: Int32
    let feedBlockMilliseconds: Int
    let firstCaptionInputMilliseconds: Int64?
    let speechToFirstCaptionMilliseconds: Int64?
    let firstCaptionWallMilliseconds: Double?
    let totalFeedWallMilliseconds: Double
    let feedWallP50Milliseconds: Double
    let feedWallP95Milliseconds: Double
    let feedWallP99Milliseconds: Double
    let committedMutationCount: Int
    let displayDivergenceCount: Int
    let tentativeEverNonempty: Bool
    let finalCommittedCharacters: Int
    let finalTentativeCharacters: Int
    let feedReceipts: [FeedReceipt]
}

private func milliseconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1_000
        + Double(components.attoseconds) / 1_000_000_000_000_000
}

private func percentile(_ values: [Double], _ quantile: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * quantile).rounded(.up)))
    return sorted[index]
}

private func run() throws {
    let configuration = try Configuration.parse(Array(CommandLine.arguments.dropFirst()))
    let fixture = try WAVFixture(path: configuration.audioPath)
    let clock = ContinuousClock()

    let loadStart = clock.now
    let model = try Model(path: configuration.modelPath, options: ModelOptions(backend: .metal))
    let loadMilliseconds = milliseconds(from: loadStart.duration(to: clock.now))
    let loadedDevice = try model.device
    guard loadedDevice.kind == "metal" else {
        throw SpikeError.gate(
            "explicit Metal request resolved to backend=\(model.backend), device-kind=\(loadedDevice.kind)"
        )
    }
    guard model.capabilities.supportsStreaming else {
        throw SpikeError.gate("model does not advertise streaming")
    }

    let family = StreamExtension.parakeetBuffered(
        ParakeetBufferedStreamOptions(
            leftMs: configuration.leftMilliseconds,
            chunkMs: configuration.chunkMilliseconds,
            rightMs: configuration.rightMilliseconds
        )
    )
    guard model.accepts(family) else {
        throw SpikeError.gate("model rejected Parakeet buffered-stream extension")
    }

    let session = try model.session()
    let stream = try session.stream(
        RunOptions(language: "en"),
        StreamOptions(commitPolicy: .stablePrefix, stablePrefixAgreementN: 3, family: family)
    )

    let runStart = clock.now
    let blockSamples = configuration.feedBlockMilliseconds * 16
    var offset = 0
    var feedIndex = 0
    var previousCommitted = ""
    var committedMutationCount = 0
    var divergenceCount = 0
    var tentativeEverNonempty = false
    var firstCaptionInputMilliseconds: Int64?
    var firstCaptionWallMilliseconds: Double?
    var feedReceipts: [FeedReceipt] = []

    while offset < fixture.samples.count {
        let end = min(offset + blockSamples, fixture.samples.count)
        let block = Array(fixture.samples[offset..<end])
        let feedStart = clock.now
        let update = try stream.feed(block)
        let wallMilliseconds = milliseconds(from: feedStart.duration(to: clock.now))
        let text = stream.text

        if !text.committed.hasPrefix(previousCommitted) { committedMutationCount += 1 }
        if text.full != text.display { divergenceCount += 1 }
        tentativeEverNonempty = tentativeEverNonempty || !text.tentative.isEmpty
        previousCommitted = text.committed

        if firstCaptionInputMilliseconds == nil, !text.display.isEmpty {
            firstCaptionInputMilliseconds = update.inputReceivedMs
            firstCaptionWallMilliseconds = milliseconds(from: runStart.duration(to: clock.now))
        }
        if configuration.showText, update.committedChanged || update.tentativeChanged {
            print("revision \(update.revision) committed=\(String(reflecting: text.committed)) tentative=\(String(reflecting: text.tentative))")
        }

        feedReceipts.append(FeedReceipt(
            index: feedIndex,
            samples: block.count,
            wallMilliseconds: wallMilliseconds,
            revision: update.revision,
            inputReceivedMilliseconds: update.inputReceivedMs,
            audioCommittedMilliseconds: update.audioCommittedMs,
            bufferedMilliseconds: update.bufferedMs,
            committedCharacters: text.committed.count,
            tentativeCharacters: text.tentative.count
        ))
        offset = end
        feedIndex += 1
    }

    _ = try stream.finalize()
    let finalText = stream.text
    if !finalText.committed.hasPrefix(previousCommitted) { committedMutationCount += 1 }
    if finalText.full != finalText.display { divergenceCount += 1 }
    tentativeEverNonempty = tentativeEverNonempty || !finalText.tentative.isEmpty
    if configuration.showText {
        print("final committed=\(String(reflecting: finalText.committed)) tentative=\(String(reflecting: finalText.tentative))")
    }

    let feedWallValues = feedReceipts.map(\.wallMilliseconds)
    let receipt = SpikeReceipt(
        runtimeCommit: "ea077b87590bcfb090d7c38c03ab36cd1c7005d3",
        backend: model.backend,
        architecture: model.arch,
        variant: model.variant,
        device: "\(loadedDevice.name) — \(loadedDevice.description)",
        modelLoadMilliseconds: loadMilliseconds,
        audioDurationMilliseconds: fixture.durationMilliseconds,
        detectedSpeechOnsetMilliseconds: fixture.speechOnsetMilliseconds,
        leftMilliseconds: configuration.leftMilliseconds,
        chunkMilliseconds: configuration.chunkMilliseconds,
        rightMilliseconds: configuration.rightMilliseconds,
        feedBlockMilliseconds: configuration.feedBlockMilliseconds,
        firstCaptionInputMilliseconds: firstCaptionInputMilliseconds,
        speechToFirstCaptionMilliseconds: firstCaptionInputMilliseconds.map {
            max(0, $0 - fixture.speechOnsetMilliseconds)
        },
        firstCaptionWallMilliseconds: firstCaptionWallMilliseconds,
        totalFeedWallMilliseconds: feedWallValues.reduce(0, +),
        feedWallP50Milliseconds: percentile(feedWallValues, 0.50),
        feedWallP95Milliseconds: percentile(feedWallValues, 0.95),
        feedWallP99Milliseconds: percentile(feedWallValues, 0.99),
        committedMutationCount: committedMutationCount,
        displayDivergenceCount: divergenceCount,
        tentativeEverNonempty: tentativeEverNonempty,
        finalCommittedCharacters: finalText.committed.count,
        finalTentativeCharacters: finalText.tentative.count,
        feedReceipts: feedReceipts
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
}

do {
    try run()
} catch SpikeError.help {
    print(SpikeError.usageText)
} catch {
    FileHandle.standardError.write(Data("said-model-spike: \(error)\n".utf8))
    exit(1)
}
