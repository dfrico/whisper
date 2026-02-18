import Foundation

final class WhisperTranscriptionService: TranscriptionService {
    private let context: WhisperContext
    private let language: String
    private let threads: Int

    init(context: WhisperContext, language: String = "en", threads: Int = 4) {
        self.context = context
        self.language = language
        self.threads = threads
    }

    func transcribe(samples: [Float]) async throws -> String {
        context.transcribe(
            samples: samples,
            language: language,
            useBeamSearch: true,
            threads: threads
        )
    }

    func transcribePartial(samples: [Float]) async throws -> String {
        context.transcribe(
            samples: samples,
            language: language,
            useBeamSearch: false,
            threads: threads
        )
    }
}
