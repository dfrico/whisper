import AVFoundation

/// Wraps AVAudioConverter to convert from hardware mic format to 16 kHz mono Float32.
final class AudioConverter {
    static let targetSampleRate: Double = 16_000
    static let targetChannels: AVAudioChannelCount = 1

    static let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: targetSampleRate,
        channels: targetChannels,
        interleaved: false
    )!

    private var converter: AVAudioConverter?

    /// Initialize the converter for a given input format.
    func prepare(inputFormat: AVAudioFormat) throws {
        guard let conv = AVAudioConverter(from: inputFormat, to: Self.outputFormat) else {
            throw AudioConverterError.converterCreationFailed
        }
        converter = conv
    }

    /// Convert an input buffer to 16 kHz mono Float32.
    /// Returns nil if conversion fails or produces no frames.
    func convert(input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }

        // Estimate output frame count based on sample rate ratio
        let ratio = Self.targetSampleRate / input.format.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1

        guard let output = AVAudioPCMBuffer(
            pcmFormat: Self.outputFormat,
            frameCapacity: estimatedFrames
        ) else { return nil }

        var error: NSError?
        var consumed = false

        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return input
        }

        guard status != .error, error == nil, output.frameLength > 0 else {
            return nil
        }

        return output
    }

    func reset() {
        converter?.reset()
        converter = nil
    }

    enum AudioConverterError: Error {
        case converterCreationFailed
    }
}
