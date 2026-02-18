import Foundation

/// Energy-based Voice Activity Detector using RMS with adaptive noise floor.
final class EnergyVAD {
    struct Result {
        let isSpeech: Bool
        let rmsLevel: Float
    }

    // Adaptive noise floor parameters
    private let noiseFloorAlpha: Float = 0.995
    private var thresholdMultiplier: Float = 3.0
    private let minimumThreshold: Float = 0.005

    // Debounce durations (in seconds)
    private let speechStartDebounce: TimeInterval = 0.150
    private let silenceEndDebounce: TimeInterval = 1.200

    // State
    private var noiseFloor: Float = 0.01
    private var isSpeechActive: Bool = false
    private var lastTransitionTime: TimeInterval = 0

    /// Process a chunk of audio samples and return VAD result.
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

    /// Set sensitivity (0.0 = least sensitive, 1.0 = most sensitive).
    /// Maps to threshold multiplier range 5.0 (least sensitive) to 1.5 (most sensitive).
    func setSensitivity(_ sensitivity: Float) {
        let clamped = max(0.0, min(1.0, sensitivity))
        thresholdMultiplier = 5.0 - clamped * 3.5 // 5.0 at 0.0, 1.5 at 1.0
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
