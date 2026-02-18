import AVFoundation
import Foundation

/// Manages AVAudioEngine capture, format conversion, ring buffer writes, and VAD dispatch.
final class AudioEngineManager {
    private let appState: AppState
    private let audioEngine = AVAudioEngine()
    private let audioConverter = AudioConverter()
    let ringBuffer: RingBuffer
    let utteranceBuffer: UtteranceBuffer
    private let energyVAD = EnergyVAD()

    private let vadQueue = DispatchQueue(label: "com.whisper.vad", qos: .userInitiated)
    private var isRunning = false
    private var wasSpeechActive = false

    /// Called on main thread when speech state transitions (true = speech started, false = speech ended).
    var onSpeechStateChanged: ((Bool) -> Void)?

    /// Lookback duration in samples to prepend on speech start (~300ms at 16kHz).
    private let lookbackSamples = 4800

    /// Input gain multiplier (1.0 = no boost).
    var inputGain: Float = 1.0

    init(appState: AppState, ringBuffer: RingBuffer = RingBuffer(), utteranceBuffer: UtteranceBuffer = UtteranceBuffer()) {
        self.appState = appState
        self.ringBuffer = ringBuffer
        self.utteranceBuffer = utteranceBuffer
    }

    func start() throws {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            throw AudioEngineError.invalidInputFormat
        }

        try audioConverter.prepare(inputFormat: hardwareFormat)
        ringBuffer.reset()
        utteranceBuffer.reset()
        energyVAD.reset()
        wasSpeechActive = false

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) {
            [weak self] buffer, time in
            self?.handleAudioBuffer(buffer, time: time)
        }

        try audioEngine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioConverter.reset()
        isRunning = false
    }

    /// Update VAD sensitivity at runtime (0.0 = least sensitive, 1.0 = most sensitive).
    func setVADSensitivity(_ sensitivity: Float) {
        energyVAD.setSensitivity(sensitivity)
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let converted = audioConverter.convert(input: buffer) else { return }
        guard let channelData = converted.floatChannelData?[0] else { return }

        let frameCount = Int(converted.frameLength)
        let gain = inputGain

        // Apply gain and copy in one pass
        var amplified = [Float](repeating: 0, count: frameCount)
        if gain != 1.0 {
            for i in 0..<frameCount {
                amplified[i] = min(max(channelData[i] * gain, -1.0), 1.0)
            }
        } else {
            amplified.withUnsafeMutableBufferPointer { dest in
                dest.baseAddress!.update(from: channelData, count: frameCount)
            }
        }

        // Write amplified samples to ring buffer
        amplified.withUnsafeBufferPointer { buf in
            ringBuffer.write(buf)
        }

        vadQueue.async { [weak self] in
            self?.processVADAndAccumulate(amplified)
        }
    }

    private func processVADAndAccumulate(_ samples: [Float]) {
        let timestamp = ProcessInfo.processInfo.systemUptime

        let result = samples.withUnsafeBufferPointer { ptr in
            energyVAD.process(ptr, timestamp: timestamp)
        }

        let normalizedLevel = min(result.rmsLevel * 5.0, 1.0)
        let isSpeech = result.isSpeech

        // Detect speech start/end transitions
        if isSpeech && !wasSpeechActive {
            // Speech started — prepend lookback from ring buffer
            let lookback = ringBuffer.read(count: lookbackSamples)
            utteranceBuffer.append(lookback)
            utteranceBuffer.append(samples)

            wasSpeechActive = true
            DispatchQueue.main.async { [weak self] in
                self?.appState.isSpeechDetected = true
                self?.appState.audioLevel = normalizedLevel
                self?.onSpeechStateChanged?(true)
            }
        } else if !isSpeech && wasSpeechActive {
            // Speech ended
            wasSpeechActive = false
            DispatchQueue.main.async { [weak self] in
                self?.appState.isSpeechDetected = false
                self?.appState.audioLevel = normalizedLevel
                self?.onSpeechStateChanged?(false)
            }
        } else {
            // During speech, accumulate audio
            if isSpeech {
                utteranceBuffer.append(samples)
            }

            DispatchQueue.main.async { [weak self] in
                self?.appState.isSpeechDetected = isSpeech
                self?.appState.audioLevel = normalizedLevel
            }
        }
    }

    enum AudioEngineError: Error {
        case invalidInputFormat
    }
}
