import Foundation

protocol TranscriptionService {
    func transcribe(samples: [Float]) async throws -> String
}

final class StubTranscriptionService: TranscriptionService {
    func transcribe(samples: [Float]) async throws -> String {
        // Stub: will be replaced by whisper.cpp integration in Milestone 4+
        return "[transcription stub]"
    }
}
