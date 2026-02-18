import Foundation
import os

/// Thread-safe accumulating buffer for the current utterance's audio samples.
/// Collects all audio from speech start to speech end for inference.
final class UtteranceBuffer {
    private var buffer: [Float] = []
    private var lock = os_unfair_lock()

    /// Append samples to the utterance buffer.
    func append(_ samples: [Float]) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        buffer.append(contentsOf: samples)
    }

    /// Read all accumulated samples (non-destructive).
    func readAll() -> [Float] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return buffer
    }

    /// Number of accumulated samples.
    var count: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return buffer.count
    }

    /// Clear the buffer for the next utterance.
    func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        buffer.removeAll(keepingCapacity: true)
    }
}
