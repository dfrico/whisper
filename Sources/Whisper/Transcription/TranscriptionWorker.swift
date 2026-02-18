import Foundation

/// Orchestrates partial (greedy) and final (beam search) inference on the inference queue.
/// All whisper_full() calls are serialized here — the context is NOT thread-safe.
final class TranscriptionWorker {
    private let service: WhisperTranscriptionService
    private let utteranceBuffer: UtteranceBuffer
    private let appState: AppState

    private let inferenceQueue = DispatchQueue(label: "com.whisper.inference", qos: .userInitiated)
    private var partialTimer: DispatchSourceTimer?
    private var jobID: UInt64 = 0
    private let maxPartialSamples = 16000 * 10 // 10 seconds at 16kHz

    var partialInterval: TimeInterval = 0.5

    init(service: WhisperTranscriptionService, utteranceBuffer: UtteranceBuffer, appState: AppState) {
        self.service = service
        self.utteranceBuffer = utteranceBuffer
        self.appState = appState
    }

    /// Start the partial inference loop (called on speech start).
    func startPartialLoop() {
        stopPartialLoop()
        jobID &+= 1
        let currentJob = jobID

        let timer = DispatchSource.makeTimerSource(queue: inferenceQueue)
        timer.schedule(deadline: .now() + partialInterval, repeating: partialInterval)
        timer.setEventHandler { [weak self] in
            self?.runPartialInference(jobID: currentJob)
        }
        timer.resume()
        partialTimer = timer
    }

    /// Stop the partial inference loop (called on speech end).
    func stopPartialLoop() {
        partialTimer?.cancel()
        partialTimer = nil
    }

    /// Run final (beam search) inference on the full utterance buffer.
    func runFinalInference(completion: @escaping (String) -> Void) {
        jobID &+= 1
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            let samples = self.utteranceBuffer.readAll()
            guard !samples.isEmpty else {
                DispatchQueue.main.async { completion("") }
                return
            }

            let text: String
            do {
                text = try syncAwait { try await self.service.transcribe(samples: samples) }
            } catch {
                text = ""
            }

            DispatchQueue.main.async {
                completion(text)
            }
        }
    }

    private func runPartialInference(jobID: UInt64) {
        guard self.jobID == jobID else { return }

        var samples = utteranceBuffer.readAll()
        guard !samples.isEmpty else { return }

        // Cap at max samples to keep partial inference fast
        if samples.count > maxPartialSamples {
            samples = Array(samples.suffix(maxPartialSamples))
        }

        let text: String
        do {
            text = try syncAwait { try await self.service.transcribePartial(samples: samples) }
        } catch {
            return
        }

        guard self.jobID == jobID else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.jobID == jobID else { return }
            self.appState.liveTranscript = text
        }
    }
}

/// Bridge async to sync for use on the inference dispatch queue.
private func syncAwait<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    Task {
        do {
            let value = try await block()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try result.get()
}
