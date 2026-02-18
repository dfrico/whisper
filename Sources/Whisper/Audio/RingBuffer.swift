import Foundation
import os

/// Lock-free (os_unfair_lock) circular buffer for Float32 audio samples.
/// Capacity: 240,000 samples = 15 seconds at 16 kHz.
final class RingBuffer {
    static let defaultCapacity = 240_000 // 15s at 16kHz

    private let capacity: Int
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var sampleCount: Int = 0
    private var lock = os_unfair_lock()

    init(capacity: Int = RingBuffer.defaultCapacity) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    /// Append samples to the ring buffer. Safe to call from the audio thread.
    func write(_ samples: UnsafeBufferPointer<Float>) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }
        sampleCount = min(sampleCount + samples.count, capacity)
    }

    /// Read the most recent `count` samples. Returns fewer if not enough data.
    func read(count: Int) -> [Float] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let available = min(count, sampleCount)
        guard available > 0 else { return [] }

        var result = [Float](repeating: 0, count: available)
        let startIndex = (writeIndex - available + capacity) % capacity

        if startIndex + available <= capacity {
            // Contiguous read
            result.withUnsafeMutableBufferPointer { dest in
                buffer.withUnsafeBufferPointer { src in
                    dest.baseAddress!.update(from: src.baseAddress! + startIndex, count: available)
                }
            }
        } else {
            // Wrapped read
            let firstPart = capacity - startIndex
            let secondPart = available - firstPart
            result.withUnsafeMutableBufferPointer { dest in
                buffer.withUnsafeBufferPointer { src in
                    dest.baseAddress!.update(from: src.baseAddress! + startIndex, count: firstPart)
                    (dest.baseAddress! + firstPart).update(from: src.baseAddress!, count: secondPart)
                }
            }
        }

        return result
    }

    /// Total samples written (clamped to capacity).
    var availableSamples: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return sampleCount
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        writeIndex = 0
        sampleCount = 0
    }
}
