import AVFoundation
import Foundation

/// Manages AVAudioEngine capture, format conversion, ring buffer writes, and VAD dispatch.
final class AudioEngineManager {
    private let appState: AppState
    private let audioEngine = AVAudioEngine()
    private let audioConverter = AudioConverter()
    private let ringBuffer = RingBuffer()
    private let energyVAD = EnergyVAD()

    private let vadQueue = DispatchQueue(label: "com.whisper.vad", qos: .userInitiated)
    private var isRunning = false

    init(appState: AppState) {
        self.appState = appState
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
        energyVAD.reset()

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

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Convert to 16kHz mono on the audio thread (lightweight)
        guard let converted = audioConverter.convert(input: buffer) else { return }
        guard let channelData = converted.floatChannelData?[0] else { return }

        let frameCount = Int(converted.frameLength)
        let samples = UnsafeBufferPointer(start: channelData, count: frameCount)

        // Write to ring buffer (lock-protected, fast)
        ringBuffer.write(samples)

        // Dispatch VAD to dedicated queue
        // Copy samples for the VAD queue since the buffer will be reused
        let samplesCopy = Array(samples)
        vadQueue.async { [weak self] in
            self?.processVAD(samplesCopy)
        }
    }

    private func processVAD(_ samples: [Float]) {
        let timestamp = ProcessInfo.processInfo.systemUptime

        let result = samples.withUnsafeBufferPointer { ptr in
            energyVAD.process(ptr, timestamp: timestamp)
        }

        // Normalize RMS to a 0-1 range for display (RMS typically 0-0.3 for speech)
        let normalizedLevel = min(result.rmsLevel * 5.0, 1.0)

        DispatchQueue.main.async { [weak self] in
            self?.appState.isSpeechDetected = result.isSpeech
            self?.appState.audioLevel = normalizedLevel
        }
    }

    enum AudioEngineError: Error {
        case invalidInputFormat
    }
}
