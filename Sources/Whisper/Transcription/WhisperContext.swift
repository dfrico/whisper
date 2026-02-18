import Foundation
import CWhisper

final class WhisperContext {
    private let ctx: OpaquePointer

    enum WhisperError: Error {
        case failedToLoadModel(String)
        case transcriptionFailed
    }

    init(modelPath: String) throws {
        var cparams = whisper_context_default_params()
        cparams.use_gpu = true
        cparams.flash_attn = false

        guard let context = whisper_init_from_file_with_params(modelPath, cparams) else {
            throw WhisperError.failedToLoadModel(modelPath)
        }
        self.ctx = context
    }

    deinit {
        whisper_free(ctx)
    }

    /// Run inference on audio samples.
    /// - Parameters:
    ///   - samples: 16kHz mono Float32 PCM audio
    ///   - language: Language code (e.g. "en") or "auto" for detection
    ///   - useBeamSearch: true for higher quality (finals), false for greedy (partials)
    ///   - threads: Number of CPU threads for decode
    /// - Returns: Transcribed text
    func transcribe(
        samples: [Float],
        language: String = "en",
        useBeamSearch: Bool = true,
        threads: Int = 4
    ) -> String {
        let strategy: whisper_sampling_strategy = useBeamSearch
            ? WHISPER_SAMPLING_BEAM_SEARCH
            : WHISPER_SAMPLING_GREEDY

        var params = whisper_full_default_params(strategy)
        params.n_threads = Int32(threads)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true

        if useBeamSearch {
            params.beam_search.beam_size = 5
        } else {
            params.greedy.best_of = 1
            params.single_segment = true
            params.no_timestamps = true
        }

        // Disable whisper's internal VAD — we use our own
        params.vad = false

        let result: Int32 = language.withCString { langPtr in
            params.language = langPtr
            return samples.withUnsafeBufferPointer { buf in
                whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
            }
        }

        guard result == 0 else { return "" }

        let segmentCount = whisper_full_n_segments(ctx)
        var text = ""
        for i in 0..<segmentCount {
            if let cStr = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: cStr)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
