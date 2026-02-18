import Foundation

final class WhisperTranscriptionService: TranscriptionService {
    private let context: WhisperContext

    init(context: WhisperContext) {
        self.context = context
    }

    func transcribe(samples: [Float]) async throws -> String {
        let settings = AppSettings()
        return context.transcribe(
            samples: samples,
            language: settings.language,
            useBeamSearch: true,
            threads: settings.cpuThreads
        )
    }

    func transcribePartial(samples: [Float]) async throws -> String {
        let settings = AppSettings()
        return context.transcribe(
            samples: samples,
            language: settings.language,
            useBeamSearch: false,
            threads: settings.cpuThreads
        )
    }
}
