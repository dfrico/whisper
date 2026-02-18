import Foundation

/// Energy-based Voice Activity Detector using RMS with adaptive noise floor.
final class EnergyVAD {
    struct Result {
        let isSpeech: Bool
        let rmsLevel: Float
    }

    // Adaptive noise floor parameters
    private let noiseFloorAlpha: Float = 0.995
    private let thresholdMultiplier: Float = 3.0
    private let minimumThreshold: Float = 0.005

    // Debounce durations (in seconds)
    private let speechStartDebounce: TimeInterval = 0.200
    private let silenceEndDebounce: TimeInterval = 0.700

    // State
    private var noiseFloor: Float = 0.01
    private var isSpeechActive: Bool = false
    private var lastTransitionTime: TimeInterval = 0

    /// Process a chunk of audio samples and return VAD result.
    /// - Parameters:
    ///   - samples: Audio samples buffer
    ///   - timestamp: Current time for debouncing
    func process(_ samples: UnsafeBufferPointer<Float>, timestamp: TimeInterval) -> Result {
        let rms = computeRMS(samples)

        // Update adaptive noise floor only during silence
        if !isSpeechActive {
            noiseFloor = noiseFloorAlpha * noiseFloor + (1.0 - noiseFloorAlpha) * rms
        }

        let threshold = max(noiseFloor * thresholdMultiplier, minimumThreshold)
        let isAboveThreshold = rms > threshold

        // Apply debouncing
        let elapsed = timestamp - lastTransitionTime

        if isAboveThreshold && !isSpeechActive {
            if elapsed >= speechStartDebounce {
                isSpeechActive = true
                lastTransitionTime = timestamp
            }
        } else if !isAboveThreshold && isSpeechActive {
            if elapsed >= silenceEndDebounce {
                isSpeechActive = false
                lastTransitionTime = timestamp
            }
        }

        return Result(isSpeech: isSpeechActive, rmsLevel: rms)
    }

    func reset() {
        noiseFloor = 0.01
        isSpeechActive = false
        lastTransitionTime = 0
    }

    private func computeRMS(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard samples.count > 0 else { return 0 }
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        return sqrtf(sumSquares / Float(samples.count))
    }
}
