import Foundation

protocol TranscriptionService {
    func transcribe(samples: [Float]) async throws -> String
    func transcribePartial(samples: [Float]) async throws -> String
}

final class StubTranscriptionService: TranscriptionService {
    func transcribe(samples: [Float]) async throws -> String {
        return "[transcription stub]"
    }

    func transcribePartial(samples: [Float]) async throws -> String {
        return "[partial stub]"
    }
}
